local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WoWStatus = ns.ContactEnricherWoWStatus or require("WhisperMessenger.Model.ContactEnricher.WoWStatus")
local BNetStatus = ns.ContactEnricherBNetStatus or require("WhisperMessenger.Model.ContactEnricher.BNetStatus")

local AvailabilityEnricher = {}

-- Check if contact is opposite faction from local player.
-- Returns true only when both factions are known and differ.
local function isOppositeFaction(itemFaction, localFaction)
  if localFaction == nil or itemFaction == nil or itemFaction == "" then
    return false
  end
  return itemFaction ~= localFaction
end

-- Expose helpers for use by ContactEnricher facade
AvailabilityEnricher.isOppositeFaction = isOppositeFaction

-- Re-export enrichClassTag from BNetStatus so ContactEnricher.lua callers
-- (BuildWindowSelectionState) can reach it via AvailabilityEnricher.enrichClassTag.
AvailabilityEnricher.enrichClassTag = BNetStatus.EnrichClassTag

function AvailabilityEnricher.ShouldRequestAvailability(_cached)
  -- Always re-request: the async whisper-check API is lightweight and ensures
  -- statuses stay fresh. A player marked CanWhisper may have gone offline,
  -- and a WrongFaction player may have come online. Re-checking every refresh
  -- cycle keeps the UI accurate without manual intervention.
  return true
end

function AvailabilityEnricher.EnrichContactsAvailability(contacts, runtime)
  local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
  for _, item in ipairs(contacts) do
    if item.guid and runtime.availabilityByGUID[item.guid] then
      WoWStatus.ApplyCached(item, runtime)
    elseif item.guid and item.channel ~= "BN" then
      WoWStatus.ApplyPresenceFallback(item, runtime)
    end
    -- WoW contacts with no availability after all checks: default to Offline
    if item.availability == nil and item.channel ~= "BN" then
      item.availability = Availability.FromStatus("Offline")
    end
    -- BNet contacts: query live status and refresh metadata from BNet API
    if item.channel == "BN" and item.bnetAccountID then
      BNetStatus.Apply(item, runtime)
    end
  end
end

ns.AvailabilityEnricher = AvailabilityEnricher
return AvailabilityEnricher
