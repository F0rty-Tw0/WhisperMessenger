local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")

local WoWStatus = {}

-- Check if contact is opposite faction from local player.
-- Returns true only when both factions are known and differ.
-- (Duplicated from AvailabilityEnricher to avoid a circular load dependency.)
local function isOppositeFaction(itemFaction, localFaction)
  if localFaction == nil or itemFaction == nil or itemFaction == "" then
    return false
  end
  return itemFaction ~= localFaction
end

-- Apply cached availability (from CAN_LOCAL_WHISPER_TARGET_RESPONSE) to a WoW contact.
-- Handles faction inference write-back, opposite-faction status correction, and
-- WrongFaction disambiguation via the Disambiguation helper.
-- Called when: item.guid and runtime.availabilityByGUID[item.guid] is set.
function WoWStatus.ApplyCached(item, runtime)
  local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
  local Disambiguation = ns.ContactEnricherDisambiguation or require("WhisperMessenger.Model.ContactEnricher.Disambiguation")
  local localFaction = runtime.localFaction

  item.availability = runtime.availabilityByGUID[item.guid]

  -- Infer and persist faction from CanWhisper status when faction is unknown.
  -- CanWhisper for a WoW contact strongly implies same faction as local player.
  -- NOTE: WrongFaction is NOT reliable for faction inference — it's a generic
  -- "unreachable" status that fires for same-faction cross-realm players too.
  -- Faction doesn't change per character, so we persist it once inferred.
  if item.factionName == nil and localFaction and item.channel ~= "BN" and item.availability.status == "CanWhisper" then
    item.factionName = localFaction
    -- Persist to conversation so we don't lose it across refreshes
    if runtime.store and item.conversationKey then
      local conversation = runtime.store.conversations[item.conversationKey]
      if conversation and conversation.factionName == nil then
        conversation.factionName = item.factionName
      end
    end
  end

  if isOppositeFaction(item.factionName, localFaction) then
    if item.availability.status == "CanWhisper" then
      -- CanWhisper + opposite faction = cross-faction guild/community member
      item.availability = Availability.FromStatus("XFaction")
    elseif item.availability.status == "WrongFaction" or item.availability.status == "Offline" then
      -- API's WrongFaction/Offline for opposite-faction is ambiguous.
      -- Guild/community presence disambiguates; otherwise faction is the real blocker.
      item.availability = Disambiguation.ResolveWrongFaction(item, runtime, true)
    end
  else
    -- Same faction or unknown faction: WrongFaction (code 2) is ambiguous —
    -- it fires for both offline players AND online cross-realm unreachable players.
    -- Check multiple sources to determine actual status.
    if item.availability.status == "WrongFaction" then
      item.availability = Disambiguation.ResolveWrongFaction(item, runtime, false)
    end
  end
end

-- Apply presence-based availability when no cached availability exists yet.
-- Uses guild/community presence as an initial status estimate.
-- Called when: item.guid set, item.channel ~= "BN", and no entry in availabilityByGUID.
function WoWStatus.ApplyPresenceFallback(item, runtime)
  local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
  local localFaction = runtime.localFaction

  -- No cached availability yet; use guild/community presence as initial status
  local presence = PresenceCache.GetPresence(item.guid)
  if presence == "online" then
    if isOppositeFaction(item.factionName, localFaction) then
      item.availability = Availability.FromStatus("XFaction")
    else
      item.availability = Availability.FromStatus("CanWhisper")
    end
  elseif presence == "offline" then
    item.availability = Availability.FromStatus("Offline")
  end
end

ns.ContactEnricherWoWStatus = WoWStatus
return WoWStatus
