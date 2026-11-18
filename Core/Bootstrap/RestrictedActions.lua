local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Thin abstraction over 12.0's C_RestrictedActions API.
--
-- The authoritative "is the player in restricted content?" source is
-- ADDON_RESTRICTION_STATE_CHANGED: it fires with (type, state) whenever a
-- restriction transitions. The state must be read from the event payload,
-- NOT re-queried via C_RestrictedActions.IsAddOnRestrictionActive, because
-- that API returns false during dispatch of its own event.
--
-- Pre-12.0 clients don't have C_RestrictedActions. There the three detection
-- flags below are the only source, so an instance answers from the cache
-- and the flags together.
local RestrictedActions = {}

-- Flag name -> field of the flag store. Only an instance reads or writes
-- these fields; everything else goes through setFlag and flag.
local FLAG_FIELDS = {
  mythic = "_inMythicContent",
  competitive = "_inCompetitiveContent",
  encounter = "_inEncounter",
}

-- A misspelled name must not read as "not restricted".
local function fieldOf(name)
  local field = FLAG_FIELDS[name]
  if field == nil then
    error("unknown restriction flag: " .. tostring(name), 3)
  end
  return field
end

-- The mythic suspend is one state for the whole addon, not per instance:
-- files with no Bootstrap handle read it through RestrictedActions.IsSuspended.
local suspended = false

-- Mirrors Enum.AddOnRestrictionType
RestrictedActions.TYPES = {
  Combat = 0,
  Encounter = 1,
  ChallengeMode = 2,
  PvPMatch = 3,
  Map = 4,
  Chat = 5,
}

-- Mirrors Enum.AddOnRestrictionState
RestrictedActions.STATES = {
  Inactive = 0,
  Activating = 1,
  Active = 2,
}

-- Missing API, an error, or a secret / non-boolean result all read as unlocked.
function RestrictedActions.ChatApiLocked()
  local chatInfo = _G.C_ChatInfo
  if type(chatInfo) ~= "table" or type(chatInfo.InChatMessagingLockdown) ~= "function" then
    return false
  end
  local ok, locked = pcall(chatInfo.InChatMessagingLockdown)
  if not ok then
    return false
  end
  local isSecret = _G.issecretvalue
  if type(isSecret) == "function" and isSecret(locked) then
    return false
  end
  return locked == true
end

-- True while the mythic suspend controller has the addon suspended.
function RestrictedActions.IsSuspended()
  return suspended
end

-- flagStore: the table that holds the detection flags under FLAG_FIELDS.
-- Bootstrap passes itself; without one the instance keeps its own.
function RestrictedActions.New(flagStore)
  local cached = {}
  local updates = {}
  local flags = flagStore or {}
  local self = {}

  -- name: "mythic", "competitive" or "encounter"; any other name is an
  -- error. Any truthy value sets the flag, and the store holds a boolean.
  function self.setFlag(name, value)
    flags[fieldOf(name)] = value and true or false
  end

  function self.flag(name)
    return flags[fieldOf(name)] and true or false
  end

  function self.updateFromEvent(restrictionType, newState)
    if type(restrictionType) ~= "number" or type(newState) ~= "number" then
      return
    end
    cached[restrictionType] = newState
    updates[restrictionType] = (updates[restrictionType] or 0) + 1
  end

  -- How many updates a type has had, to tell whether a new one arrived since.
  function self.updateCount(restrictionType)
    return updates[restrictionType] or 0
  end

  -- The last state the event reported for a type, or nil if none arrived.
  function self.cachedState(restrictionType)
    return cached[restrictionType]
  end

  function self.isActive(restrictionType)
    local s = cached[restrictionType]
    if s ~= nil then
      return s == RestrictedActions.STATES.Active or s == RestrictedActions.STATES.Activating
    end
    local api = _G.C_RestrictedActions
    if api and type(api.IsAddOnRestrictionActive) == "function" then
      local ok, result = pcall(api.IsAddOnRestrictionActive, restrictionType)
      if ok then
        return result == true
      end
    end
    return false
  end

  function self.isChatLocked()
    return self.isActive(RestrictedActions.TYPES.Chat) or RestrictedActions.ChatApiLocked()
  end

  -- A chat lock behaves exactly like restricted content.
  function self.isCompetitive()
    return self.isActive(RestrictedActions.TYPES.Encounter)
      or self.isActive(RestrictedActions.TYPES.ChallengeMode)
      or self.isActive(RestrictedActions.TYPES.PvPMatch)
      or self.isChatLocked()
      or self.flag("competitive")
      or self.flag("encounter")
  end

  function self.isMythic()
    return self.isActive(RestrictedActions.TYPES.ChallengeMode) or self.flag("mythic")
  end

  function self.isRestricted()
    return self.isCompetitive() or self.isMythic()
  end

  -- Writes the addon-wide suspend: every instance and IsSuspended see it.
  function self.setSuspended(value)
    suspended = value and true or false
  end

  function self.isSuspended()
    return suspended
  end

  return self
end

-- The instance that answers for owner (the Bootstrap table). Bootstrap.Initialize
-- installs one per runtime. An owner asked before that gets one over its own
-- flag fields: the lockdown catcher's frame is live before Initialize.
function RestrictedActions.For(owner)
  local restrictions = owner.restrictions
  if restrictions == nil then
    restrictions = RestrictedActions.New(owner)
    owner.restrictions = restrictions
  end
  return restrictions
end

ns.BootstrapRestrictedActions = RestrictedActions
return RestrictedActions
