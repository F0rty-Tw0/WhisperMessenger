local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")

local Disambiguation = {}

-- Resolve ambiguous WrongFaction/Offline status for a contact using multiple
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
--   WrongFaction for same-faction means "cross-realm unreachable", NOT a hard
--   whisper block. Four-step resolution: presence → BNet friend → group member
--   → optimistic CanWhisper fallback.
--     presence online   → CanWhisper
--     presence offline  → Offline
--     BNet friend online→ Away/Busy/CanWhisper
--     group member      → CanWhisper
--     no corroboration  → CanWhisper (optimistic)
function Disambiguation.ResolveWrongFaction(item, runtime, isOpposite)
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

  -- Same faction or unknown faction: WrongFaction (code 2) is ambiguous —
  -- it fires for both offline players AND online cross-realm unreachable players.
  -- Check multiple sources to determine actual status.

  -- 1. Guild/community presence cache
  if presence == "online" then
    return Availability.FromStatus("CanWhisper")
  elseif presence == "offline" then
    return Availability.FromStatus("Offline")
  end

  -- 2. BNet friend check (covers cross-realm BNet friends)
  local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
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

  -- 4. Fallback: CanWhisper (optimistic). API's WrongFaction for same-faction
  -- means "cross-realm unreachable via whisper-check", not a hard whisper block.
  -- Whispers can still land even without corroborating online proof.
  return Availability.FromStatus("CanWhisper")
end

ns.ContactEnricherDisambiguation = Disambiguation
return Disambiguation
