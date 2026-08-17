local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon
  or (type(require) == "function" and require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common"))
  or nil

local TimeFormat = ns.TimeFormat or (type(require) == "function" and require("WhisperMessenger.Util.TimeFormat")) or nil
local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil
local function L(key)
  return Localization and Localization.Text(key) or key
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

local function appendLeftMessage(conversation, channel, now)
  conversation.messages = conversation.messages or {}
  local text = L(LEFT_LABEL[channel] or "Left group")
  local timeStr = TimeFormat and TimeFormat.MessageTime and TimeFormat.MessageTime(now) or ""
  if timeStr ~= "" then
    text = text .. ", " .. timeStr
  end
  table.insert(conversation.messages, {
    id = tostring(now) .. "-left-" .. channel,
    kind = "system",
    direction = "in",
    text = text,
    sentAt = now,
    channel = channel,
  })
  conversation.lastActivityAt = now
  conversation.lastPreview = text
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

local function closeGroupSession(Bootstrap, category, partyGUID, deps)
  local runtime = Bootstrap and Bootstrap.runtime
  local state = runtime and (runtime.accountState or runtime.store)
  local localProfileId = runtime and runtime.localProfileId
  if state == nil or state.conversations == nil or type(localProfileId) ~= "string" or localProfileId == "" then
    return true
  end

  local now = currentTime()
  local changed = false
  for channel, prefix in pairs(CHANNEL_KEY_PREFIX) do
    local key = prefix .. localProfileId .. "::" .. category .. "::" .. partyGUID
    local conversation = state.conversations[key]
    if conversation and not conversation.leftGroup then
      appendLeftMessage(conversation, channel, now)
      conversation.leftGroup = true
      changed = true
    end
  end

  if changed then
    if deps and deps.trace then
      deps.trace("GroupMembership: closed group session")
    end
    if Common and Common.refreshRuntimeWindow then
      Common.refreshRuntimeWindow(Bootstrap)
    end
  end

  return true
end

function GroupMembership.handleGroupJoined(Bootstrap, category, partyGUID, deps)
  local runtime = Bootstrap and Bootstrap.runtime
  if runtime == nil or type(category) ~= "number" or not validPartyGUID(partyGUID) then
    return true
  end

  runtime.groupPartyGUIDsByCategory = runtime.groupPartyGUIDsByCategory or {}
  local previousPartyGUID = runtime.groupPartyGUIDsByCategory[category]
  if validPartyGUID(previousPartyGUID) and previousPartyGUID ~= partyGUID then
    closeGroupSession(Bootstrap, category, previousPartyGUID, deps)
  end
  runtime.groupPartyGUIDsByCategory[category] = partyGUID
  return true
end

function GroupMembership.handleGroupLeft(Bootstrap, category, partyGUID, deps)
  local runtime = Bootstrap and Bootstrap.runtime
  if runtime == nil or type(category) ~= "number" or not validPartyGUID(partyGUID) then
    return true
  end

  local partyGUIDs = runtime.groupPartyGUIDsByCategory
  if partyGUIDs and partyGUIDs[category] == partyGUID then
    partyGUIDs[category] = nil
  end

  return closeGroupSession(Bootstrap, category, partyGUID, deps)
end

-- GROUP_ROSTER_UPDATE is a fallback for legacy rows and clients that cannot
-- provide party GUID lifecycle events. It must not reopen a closed GUID row.
function GroupMembership.handleGroupRosterUpdate(Bootstrap, deps)
  if _G.IsInGroup == nil then
    return true
  end

  local runtime = Bootstrap.runtime
  local state = runtime and (runtime.accountState or runtime.store)
  if state == nil or state.conversations == nil then
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
      local conversation = state.conversations[key]
      if conversation ~= nil then
        if membership then
          if conversation.leftGroup then
            conversation.leftGroup = nil
            changed = true
          end
        elseif not conversation.leftGroup then
          appendLeftMessage(conversation, channel, now)
          conversation.leftGroup = true
          changed = true
        end
      end
    end
  end

  if changed then
    if deps and deps.trace then
      deps.trace("GroupMembership: marked legacy group membership transition(s)")
    end
    if Common and Common.refreshRuntimeWindow then
      Common.refreshRuntimeWindow(Bootstrap)
    end
  end

  return true
end

ns.BootstrapLifecycleHandlersGroupMembership = GroupMembership
return GroupMembership
