local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AddonComm = ns.AddonComm or require("WhisperMessenger.Transport.AddonComm")
local GroupChats = ns.GroupChats or require("WhisperMessenger.Model.GroupChats")
local GroupChatProtocol = ns.GroupChatProtocol or require("WhisperMessenger.Model.GroupChatProtocol")
local SafeText = ns.GroupChatProtocolSafeText or require("WhisperMessenger.Model.GroupChatProtocol.SafeText")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Writer = ns.GroupChatConversationWriter or require("WhisperMessenger.Core.GroupChat.ConversationWriter")

-- Incoming group chat packets (CHAT_MSG_ADDON on the group chat prefix).
--
-- Anyone may add the player to a group, like anyone may whisper them; a
-- blocked player's packets are dropped. Member lists only ever grow from a
-- roster ("R"): people leave with an explicit "L", so a stale list can't
-- remove anyone. A line for a group this client never heard of creates it
-- with just the sender and asks them for the full list ("Q").
local Inbox = {}

local function L(key)
  return Localization.Text(key)
end

-- Meta for the event bridge: a chat line may alert like a whisper.
local MESSAGE_META = { groupChatMessage = true }

function Inbox.New(runtime, service)
  local registry = service.registry
  local buffer = {}

  local function now()
    return type(runtime.now) == "function" and runtime.now() or 0
  end

  local function isBlocked(sender, current)
    local filters = runtime.accountState and runtime.accountState.filters
    if type(filters) ~= "table" or type(filters.ignored) ~= "table" or next(filters.ignored) == nil then
      return false
    end
    return IgnoreList.Lookup(filters, sender, current) ~= nil
  end

  -- Roster names carry their realm; keep them the local way.
  local function addFromRoster(group, sender, members)
    local realm = LocalPlayer.NormalizedRealm()
    local incoming = { sender }
    for _, member in ipairs(members or {}) do
      local name = GroupChats.FullName(member, realm)
      if name then
        incoming[#incoming + 1] = name
      end
    end
    return GroupChats.AddMembers(group, incoming, service.SelfName())
  end

  local function namesList(names)
    local shown = {}
    for _, name in ipairs(names) do
      shown[#shown + 1] = service.DisplayName(name)
    end
    return table.concat(shown, ", ")
  end

  local function onRoster(sender, packet, current)
    local group = GroupChats.Find(registry, packet.groupId)
    local senderName = service.DisplayName(sender)
    if group == nil or group.left == true then
      if group == nil then
        group = GroupChats.Create(registry, { id = packet.groupId, name = packet.name, members = {}, createdAt = current })
      end
      group.left = nil
      group.name = packet.name or group.name
      addFromRoster(group, sender, packet.members)
      if group.name == "" then
        group.name = GroupChats.DefaultName(group.members)
      end
      return Writer.AppendNotice(runtime, group, string.format(L("%s added you to the group chat."), senderName), current)
    end

    local conversation
    if packet.name and packet.name ~= group.name then
      group.name = packet.name
      conversation = Writer.AppendNotice(runtime, group, string.format(L("%s named the group %s."), senderName, packet.name), current)
    end
    local added = addFromRoster(group, sender, packet.members)
    -- The sender is the one member whose arrival nobody announced.
    local announced = {}
    for _, name in ipairs(added) do
      if not GroupChats.SameName(name, sender) then
        announced[#announced + 1] = name
      end
    end
    if #announced > 0 then
      conversation = Writer.AppendNotice(runtime, group, string.format(L("%s added %s."), senderName, namesList(announced)), current)
    end
    return conversation or (Writer.Ensure(runtime, group, nil))
  end

  local function onMessage(sender, packet, current)
    local group = GroupChats.Find(registry, packet.groupId)
    if group ~= nil and group.left == true then
      -- They still count us in: tell them we're gone.
      service.SendLeave(group.id, { sender })
      return nil
    end
    local text = SafeText.Clean(packet.text)
    if text == nil then
      return nil
    end
    if group == nil then
      group = GroupChats.Create(registry, { id = packet.groupId, members = { sender }, createdAt = current, selfName = service.SelfName() })
      service.SendQuery(group.id, sender)
    elseif not GroupChats.IsMember(group, sender) then
      GroupChats.AddMembers(group, { sender }, service.SelfName())
    end
    local conversation = Writer.AppendIncoming(runtime, group, sender, text, current)
    return conversation, MESSAGE_META
  end

  local function onLeave(sender, packet, current)
    local group = GroupChats.Find(registry, packet.groupId)
    if group == nil or group.left == true or not GroupChats.RemoveMember(group, sender) then
      return nil
    end
    return Writer.AppendNotice(runtime, group, string.format(L("%s left the group chat."), service.DisplayName(sender)), current)
  end

  local function onQuery(sender, packet)
    local group = GroupChats.Find(registry, packet.groupId)
    if group ~= nil and group.left ~= true and GroupChats.IsMember(group, sender) then
      service.SendRoster(group, { sender })
    end
    return nil
  end

  local handlers = {
    roster = onRoster,
    message = onMessage,
    leave = onLeave,
    query = onQuery,
  }

  local inbox = {}

  -- payload: { prefix, text, channel, playerName } from CHAT_MSG_ADDON.
  -- Returns the conversation that changed (and meta), or nil.
  function inbox.HandleAddonMessage(payload)
    if type(payload) ~= "table" or payload.prefix ~= AddonComm.PREFIX_GROUP_CHAT or payload.channel ~= "WHISPER" then
      return nil
    end
    local sender = GroupChats.FullName(payload.playerName, LocalPlayer.NormalizedRealm())
    if sender == nil or GroupChats.SameName(sender, service.SelfName()) then
      return nil
    end
    local current = now()
    if isBlocked(sender, current) then
      return nil
    end
    service.outbox.MarkOnline(sender)
    local body = GroupChatProtocol.Receive(buffer, sender, payload.text, current)
    local packet = body and GroupChatProtocol.Decode(body)
    local handler = packet and handlers[packet.kind]
    if handler == nil then
      return nil
    end
    local conversation, meta = handler(sender, packet, current)
    return conversation, meta
  end

  return inbox
end

ns.GroupChatInbox = Inbox
return Inbox
