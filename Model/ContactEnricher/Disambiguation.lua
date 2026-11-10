local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")

local Disambiguation = {}

-- Resolve a WrongFaction/Offline status for a contact using multiple
-- corroborating sources. The resolution differs by faction relationship:
--
-- Opposite-faction path (isOpposite = true):
--   Guild/community presence disambiguates. No BNet/group fallback —
--   only presence is checked. Falls through to WrongFaction if unknown.
--     online  → XFaction
--     offline → Offline
--     unknown → WrongFaction
--
-- Same-faction path (isOpposite = false / nil):
--   Four-step resolution: presence → BNet friend → group member → fallback.
--     presence online   → CanWhisper
--     presence offline  → Offline
--     BNet friend online→ Away/Busy/CanWhisper
--     group member      → CanWhisper
--     no corroboration  → fallbackStatus
--   fallbackStatus is "CanWhisper" (optimistic) by default, for a same-faction
--   WrongFaction the whisper check cannot reach. Pass "Offline" when the
--   whisper check said Offline: with no proof of life it stays Offline.
function Disambiguation.ResolveWrongFaction(item, runtime, isOpposite, fallbackStatus)
  local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")

  local presence = PresenceCache.GetPresence(item.guid)

  if isOpposite then
    -- Opposite-faction: presence-only disambiguation, no BNet/group fallback
    if presence == "online" then
      return Availability.FromStatus("XFaction")
    elseif presence == "offline" then
      return Availability.FromStatus("Offline")
    else
      return Availability.FromStatus("WrongFaction")
    end
  end

  -- Same faction or unknown faction: check multiple sources for proof of life.

  -- 1. Guild/community presence cache
  if presence == "online" then
    return Availability.FromStatus("CanWhisper")
  elseif presence == "offline" then
    return Availability.FromStatus("Offline")
  end

  -- 2. BNet friend check (covers cross-realm BNet friends)
  local function findBNetFriendByGUID(guid, bnetApi)
    if guid == nil or type(bnetApi) ~= "table" then
      return nil
    end
    if type(bnetApi.GetAccountInfoByGUID) == "function" then
      local ok, info = pcall(bnetApi.GetAccountInfoByGUID, guid)
      if ok and info and (info.isOnline or info.isAFK or info.isDND) then
        return info
      end
    end
    return nil
  end
  local bnetInfo = findBNetFriendByGUID(item.guid, runtime.bnetApi)
  if bnetInfo then
    local bnetStatus = "CanWhisper"
    if bnetInfo.isAFK then
      bnetStatus = "Away"
    elseif bnetInfo.isDND then
      bnetStatus = "Busy"
    end
    return Availability.FromStatus(bnetStatus)
  end

  -- 3. Party/raid member check
  local function isGroupMemberOnline(displayName)
    if displayName == nil then
      return false
    end
    local UnitIsConnected = _G["UnitIsConnected"]
    local UnitName = _G["UnitName"]
    local GetNumGroupMembers = _G["GetNumGroupMembers"]
    if type(UnitIsConnected) ~= "function" or type(UnitName) ~= "function" then
      return false
    end
    local numMembers = type(GetNumGroupMembers) == "function" and GetNumGroupMembers() or 0
    if numMembers == 0 then
      return false
    end
    -- Normalize: compare lowercase name before realm separator
    local targetName = string.lower(string.match(displayName, "^([^%-]+)") or displayName)
    local IsInRaid = _G["IsInRaid"]
    local prefix = (type(IsInRaid) == "function" and IsInRaid()) and "raid" or "party"
    for i = 1, numMembers do
      local unit = prefix .. i
      local name = UnitName(unit)
      if name and string.lower(name) == targetName then
        return UnitIsConnected(unit) == true
      end
    end
    return false
  end
  if isGroupMemberOnline(item.displayName or item.playerName) then
    return Availability.FromStatus("CanWhisper")
  end

  -- 4. Fallback. Default CanWhisper (optimistic): WrongFaction for same-faction
  -- means "cross-realm unreachable via whisper-check", not a hard whisper block.
  -- Whispers can still land even without corroborating online proof.
  return Availability.FromStatus(fallbackStatus or "CanWhisper")
end

ns.ContactEnricherDisambiguation = Disambiguation
return Disambiguation
