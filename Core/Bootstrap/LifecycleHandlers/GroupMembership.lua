local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local TimeFormat = ns.TimeFormat or require("WhisperMessenger.Util.TimeFormat")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local function L(key)
  return Localization.Text(key)
end

local GroupMembership = {}

-- Label shown as a system message when the player leaves a given group type.
local LEFT_LABEL = {
  PARTY = "Left party",
  INSTANCE_CHAT = "Left instance",
  RAID = "Left raid",
}

local function currentTime()
  if type(_G.time) == "function" then
    return _G.time() or 0
  end
  return 0
end

-- Leaving is not chat: the line goes through the store's retention
-- bookkeeping but leaves the chat's last activity alone, so a group you keep
-- leaving and rejoining still ages out from its last real message.
local function appendLeftMessage(store, key, channel, now)
  local text = L(LEFT_LABEL[channel] or "Left group")
  local timeStr = TimeFormat.MessageTime(now)
  if timeStr ~= "" then
    text = text .. ", " .. timeStr
  end
  Store.AppendNotice(store, key, {
    id = tostring(now) .. "-left-" .. channel,
    kind = "system",
    direction = "in",
    text = text,
    sentAt = now,
    channel = channel,
  })
end

-- Legacy group histories use "<prefix><profileId>". GUID-scoped histories
-- append "::category::partyGUID" and are stamped during ingest.
local CHANNEL_KEY_PREFIX = {
  PARTY = "party::",
  RAID = "raid::",
  INSTANCE_CHAT = "instance::",
}

local function homeCategory()
  return type(_G.LE_PARTY_CATEGORY_HOME) == "number" and _G.LE_PARTY_CATEGORY_HOME or 1
end

local function instanceCategory()
  return type(_G.LE_PARTY_CATEGORY_INSTANCE) == "number" and _G.LE_PARTY_CATEGORY_INSTANCE or 2
end

local function categoryForChannel(channel)
  if channel == "PARTY" or channel == "RAID" then
    return homeCategory()
  end
  if channel == "INSTANCE_CHAT" then
    return instanceCategory()
  end
  return nil
end

local function validPartyGUID(partyGUID)
  return type(partyGUID) == "string" and partyGUID ~= ""
end

local function closeGroupSession(Bootstrap, category, partyGUID)
  local runtime = Bootstrap and Bootstrap.runtime
  local store = runtime and runtime.store
  local localProfileId = runtime and runtime.localProfileId
  if store == nil or store.conversations == nil or type(localProfileId) ~= "string" or localProfileId == "" then
    return true
  end

  local now = currentTime()
  local changed = false
  for channel, prefix in pairs(CHANNEL_KEY_PREFIX) do
    local key = prefix .. localProfileId .. "::" .. category .. "::" .. partyGUID
    local conversation = store.conversations[key]
    if conversation and not conversation.leftGroup then
      appendLeftMessage(store, key, channel, now)
      conversation.leftGroup = true
      changed = true
    end
  end

  if changed then
    Common.refreshRuntimeWindow(Bootstrap)
  end

  return true
end

-- Relog can report GROUP_LEFT then GROUP_JOINED for the same party GUID;
-- that is the same group, so its thread becomes writable again.
local function reopenGroupSession(Bootstrap, category, partyGUID)
  local runtime = Bootstrap.runtime
  local store = runtime.store
  local localProfileId = runtime.localProfileId
  if store == nil or store.conversations == nil or type(localProfileId) ~= "string" or localProfileId == "" then
    return
  end

  local changed = false
  for _, prefix in pairs(CHANNEL_KEY_PREFIX) do
    local conversation = store.conversations[prefix .. localProfileId .. "::" .. category .. "::" .. partyGUID]
    if conversation and conversation.leftGroup then
      conversation.leftGroup = nil
      changed = true
    end
  end

  if changed then
    Common.refreshRuntimeWindow(Bootstrap)
  end
end

function GroupMembership.handleGroupJoined(Bootstrap, category, partyGUID)
  local runtime = Bootstrap and Bootstrap.runtime
  if runtime == nil or type(category) ~= "number" or not validPartyGUID(partyGUID) then
    return true
  end

  runtime.groupPartyGUIDsByCategory = runtime.groupPartyGUIDsByCategory or {}
  local previousPartyGUID = runtime.groupPartyGUIDsByCategory[category]
  if validPartyGUID(previousPartyGUID) and previousPartyGUID ~= partyGUID then
    closeGroupSession(Bootstrap, category, previousPartyGUID)
  end
  runtime.groupPartyGUIDsByCategory[category] = partyGUID
  reopenGroupSession(Bootstrap, category, partyGUID)
  return true
end

function GroupMembership.handleGroupLeft(Bootstrap, category, partyGUID)
  local runtime = Bootstrap and Bootstrap.runtime
  if runtime == nil or type(category) ~= "number" or not validPartyGUID(partyGUID) then
    return true
  end

  local partyGUIDs = runtime.groupPartyGUIDsByCategory
  if partyGUIDs and partyGUIDs[category] == partyGUID then
    partyGUIDs[category] = nil
  end

  return closeGroupSession(Bootstrap, category, partyGUID)
end

-- GROUP_ROSTER_UPDATE is a fallback for legacy rows and clients that cannot
-- provide party GUID lifecycle events. It must not reopen a closed GUID row.
function GroupMembership.handleGroupRosterUpdate(Bootstrap)
  if _G.IsInGroup == nil then
    return true
  end

  local runtime = Bootstrap.runtime
  local store = runtime and runtime.store
  if store == nil or store.conversations == nil then
    return true
  end

  local localProfileId = runtime and runtime.localProfileId
  if type(localProfileId) ~= "string" or localProfileId == "" then
    -- Without a profileId we can't reliably scope the transition to the
    -- current character; bail rather than risk flipping foreign history.
    return true
  end

  local inGroup = {
    PARTY = _G.IsInGroup(homeCategory()) and true or false,
    INSTANCE_CHAT = _G.IsInGroup(instanceCategory()) and true or false,
    RAID = (type(_G.IsInRaid) == "function" and _G.IsInRaid()) and true or false,
  }

  local partyGUIDs = runtime.groupPartyGUIDsByCategory
  local now = currentTime()
  local changed = false

  for channel, membership in pairs(inGroup) do
    local category = categoryForChannel(channel)
    local partyGUID = partyGUIDs and partyGUIDs[category]
    if not validPartyGUID(partyGUID) then
      local prefix = CHANNEL_KEY_PREFIX[channel]
      local key = prefix .. localProfileId
      local conversation = store.conversations[key]
      if conversation ~= nil then
        if membership then
          if conversation.leftGroup then
            conversation.leftGroup = nil
            changed = true
          end
        elseif not conversation.leftGroup then
          appendLeftMessage(store, key, channel, now)
          conversation.leftGroup = true
          changed = true
        end
      end
    end
  end

  if changed then
    Common.refreshRuntimeWindow(Bootstrap)
  end

  return true
end

ns.BootstrapLifecycleHandlersGroupMembership = GroupMembership
return GroupMembership
