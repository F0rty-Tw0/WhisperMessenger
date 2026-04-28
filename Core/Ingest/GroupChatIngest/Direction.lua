local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Direction = {}

local function rawGuidEqual(a, b)
  return a == b
end

local function compareGuids(a, b)
  if a == nil or b == nil then
    return false
  end
  local ok, equal = pcall(rawGuidEqual, a, b)
  return ok and equal == true
end

-- Resolve the local player's GUID. Prefer the cached state value; fall back
-- to live _G.UnitGUID("player") so direction detection works even when the
-- runtime was created before player identity was available (ADDON_LOADED
-- fires before PLAYER_ENTERING_WORLD on a cold boot).
local function resolveLocalPlayerGuid(state)
  if type(state.localPlayerGuid) == "string" and state.localPlayerGuid ~= "" then
    return state.localPlayerGuid
  end
  if type(_G.UnitGUID) == "function" then
    local ok, guid = pcall(_G.UnitGUID, "player")
    if ok and type(guid) == "string" and guid ~= "" then
      state.localPlayerGuid = guid
      return guid
    end
  end
  return nil
end

-- Resolve returns "out" when the message was sent by the local player,
-- "in" otherwise.
function Direction.Resolve(eventName, payload, state)
  if eventName == "CHAT_MSG_BN_CONVERSATION" then
    -- No guid on BN conversation events; use bnetAccountID comparison
    if state.localBnetAccountID ~= nil and payload.bnSenderID == state.localBnetAccountID then
      return "out"
    end
    return "in"
  end

  -- For every other group surface: compare guid to the local player's guid.
  local localGuid = resolveLocalPlayerGuid(state)
  if compareGuids(payload.guid, localGuid) then
    return "out"
  end
  return "in"
end

-- CompareGuids wraps guid equality in a pcall to swallow 12.0 secret-string
-- throws (comparing a tainted guid raises from an addon-tainted call stack).
function Direction.CompareGuids(a, b)
  return compareGuids(a, b)
end

ns.GroupChatIngestDirection = Direction

return Direction
