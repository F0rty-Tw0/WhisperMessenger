local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local GroupChats = ns.GroupChats or require("WhisperMessenger.Model.GroupChats")
local GroupChatProtocol = ns.GroupChatProtocol or require("WhisperMessenger.Model.GroupChatProtocol")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Outbox = ns.GroupChatOutbox or require("WhisperMessenger.Core.GroupChat.Outbox")
local Writer = ns.GroupChatConversationWriter or require("WhisperMessenger.Core.GroupChat.ConversationWriter")
local Inbox = ns.GroupChatInbox or require("WhisperMessenger.Core.GroupChat.Inbox")

-- Group chats without a party: create, add people, rename, leave and send.
-- Every line goes to each member as an addon whisper (see Outbox), so all
-- members need Whisper Messenger; incoming packets are handled by Inbox.
local GroupChatService = {}

local function L(key)
  return Localization.Text(key)
end

-- options: runtime, addonComm, timer, random.
function GroupChatService.Create(options)
  options = options or {}
  local runtime = options.runtime or {}
  local accountState = runtime.accountState or {}
  local registry = GroupChats.Ensure(accountState)
  local random = options.random or math.random

  local function now()
    return type(runtime.now) == "function" and runtime.now() or 0
  end

  local outbox = Outbox.New({
    chatApi = runtime.chatApi,
    addonComm = options.addonComm,
    timer = options.timer,
    random = random,
    now = now,
  })

  local service = { registry = registry, outbox = outbox }

  function service.SelfName()
    local name = LocalPlayer.Name()
    local realm = LocalPlayer.NormalizedRealm()
    if name and realm then
      return name .. "-" .. realm
    end
    return name
  end

  function service.DisplayName(fullName)
    return GroupChats.MemberSummary({ members = { fullName } }, LocalPlayer.NormalizedRealm())
  end

  local function isPaused()
    return type(runtime.isCompetitiveContent) == "function" and runtime.isCompetitiveContent() == true
  end

  local function fullMemberList(group)
    local members = { service.SelfName() }
    for _, member in ipairs(group.members) do
      members[#members + 1] = member
    end
    return members
  end

  function service.SendRoster(group, recipients)
    local body = GroupChatProtocol.EncodeRoster(group.id, group.name, fullMemberList(group))
    return body and outbox.Send(recipients or group.members, body)
  end

  function service.SendLeave(groupId, recipients)
    local body = GroupChatProtocol.EncodeLeave(groupId)
    return body and outbox.Send(recipients, body)
  end

  function service.SendQuery(groupId, recipient)
    local body = GroupChatProtocol.EncodeQuery(groupId)
    return body and outbox.Send({ recipient }, body)
  end

  function service.FindByConversationKey(conversationKey)
    return GroupChats.Find(registry, GroupChats.IdFromConversationKey(conversationKey))
  end

  local function namesList(names)
    local shown = {}
    for _, name in ipairs(names) do
      shown[#shown + 1] = service.DisplayName(name)
    end
    return table.concat(shown, ", ")
  end

  -- Returns the new conversation key, or nil and a localized reason.
  function service.Create(namesText)
    if isPaused() then
      return nil, L("Group chats are paused here.")
    end
    local names = GroupChats.ParseNames(namesText, LocalPlayer.NormalizedRealm(), service.SelfName())
    if #names == 0 then
      return nil, L("Enter at least one player name.")
    end
    local id = GroupChats.NewId(random)
    while registry[id] ~= nil do
      id = GroupChats.NewId(random)
    end
    local current = now()
    local group = GroupChats.Create(registry, { id = id, members = names, createdAt = current, selfName = service.SelfName() })
    local _, conversationKey = Writer.Ensure(runtime, group, current)
    Writer.AppendNotice(runtime, group, string.format(L("You started a group chat with %s."), namesList(group.members)), current)
    service.SendRoster(group)
    return conversationKey
  end

  local function joinedGroup(groupId)
    local group = GroupChats.Find(registry, groupId)
    if group == nil or group.left == true then
      return nil
    end
    return group
  end

  -- Returns how many were added, or nil and a localized reason.
  function service.AddMembers(groupId, namesText)
    local group = joinedGroup(groupId)
    if group == nil then
      return nil
    end
    if isPaused() then
      return nil, L("Group chats are paused here.")
    end
    if #group.members >= GroupChats.MAX_MEMBERS then
      return nil, L("This group chat is full.")
    end
    local names = GroupChats.ParseNames(namesText, LocalPlayer.NormalizedRealm(), service.SelfName())
    local added = GroupChats.AddMembers(group, names, service.SelfName())
    if #added == 0 then
      return nil, L("Enter at least one player name.")
    end
    Writer.AppendNotice(runtime, group, string.format(L("You added %s."), namesList(added)), now())
    service.SendRoster(group)
    return #added
  end

  function service.Rename(groupId, name)
    local group = joinedGroup(groupId)
    local cleanName = GroupChats.CleanName(name)
    if group == nil or cleanName == nil or cleanName == group.name or isPaused() then
      return false
    end
    group.name = cleanName
    Writer.AppendNotice(runtime, group, string.format(L("You named the group %s."), cleanName), now())
    service.SendRoster(group)
    return true
  end

  function service.Leave(groupId)
    local group = joinedGroup(groupId)
    if group == nil or isPaused() then
      return false
    end
    service.SendLeave(group.id, group.members)
    group.left = true
    Writer.AppendNotice(runtime, group, L("You left the group chat."), now())
    return true
  end

  -- The composer's send for a group chat conversation.
  function service.Send(conversationKey, text)
    local group = service.FindByConversationKey(conversationKey)
    if group == nil or group.left == true or isPaused() or type(text) ~= "string" or text == "" then
      return false
    end
    local body = GroupChatProtocol.EncodeMessage(group.id, text)
    if body == nil or outbox.Send(group.members, body) == nil then
      return false
    end
    Writer.AppendOutgoing(runtime, group, text, now())
    return true
  end

  -- Why the composer can't send here, as a localized notice, or nil.
  function service.Notice(conversationKey)
    local group = service.FindByConversationKey(conversationKey)
    if group == nil then
      return L("Group chat not found.")
    end
    if group.left == true then
      return L("You left this group chat.")
    end
    if isPaused() then
      return L("Group chats are paused here.")
    end
    if #group.members == 0 then
      return L("Nobody else is in this group chat.")
    end
    return nil
  end

  -- Re-creates the conversation of every joined group (retention or "Clear
  -- all chats" may have removed it), so each one keeps a row.
  function service.EnsureConversations()
    for _, group in ipairs(GroupChats.Joined(registry)) do
      Writer.Ensure(runtime, group, nil)
    end
  end

  local inbox = Inbox.New(runtime, service)
  service.HandleAddonMessage = inbox.HandleAddonMessage

  -- A "No player named ..." line answering one of our sends. True when it
  -- was ours.
  function service.HandleSystemMessage(text)
    return outbox.ClaimNotFound(text) ~= nil
  end

  function service.ExpectsSystemMessage()
    return outbox.HasRecentSends()
  end

  return service
end

ns.GroupChatService = GroupChatService
return GroupChatService
