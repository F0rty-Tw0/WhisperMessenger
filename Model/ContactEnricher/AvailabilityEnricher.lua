local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WoWStatus = ns.ContactEnricherWoWStatus or require("WhisperMessenger.Model.ContactEnricher.WoWStatus")
local BNetStatus = ns.ContactEnricherBNetStatus or require("WhisperMessenger.Model.ContactEnricher.BNetStatus")
local OnlineWatch = ns.OnlineWatch or require("WhisperMessenger.Model.OnlineWatch")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")

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

function AvailabilityEnricher.ShouldRequestAvailability(_cached)
  -- Always re-request: the async whisper-check API is lightweight and ensures
  -- statuses stay fresh. A player marked CanWhisper may have gone offline,
  -- and a WrongFaction player may have come online. Re-checking every refresh
  -- cycle keeps the UI accurate without manual intervention.
  return true
end

-- Statuses that prove the contact is logged in right now.
local ONLINE_STATUSES = { CanWhisper = true, XFaction = true, Away = true, Busy = true, BNetOnline = true }

-- Only proof counts: Battle.net status, or the game's own whisper check
-- (cached). A roster or optimistic guess must not claim "seen now".
local function isProvenOnline(item, runtime)
  if not ONLINE_STATUSES[item.availability and item.availability.status] then
    return false
  end
  if item.channel == "BN" then
    return true
  end
  local cached = item.guid and runtime.availabilityByGUID[item.guid]
  return cached ~= nil and cached.canWhisper == true
end

-- "Last seen" for the header: stamped from this refresh, which already runs;
-- never a scan of its own.
local function stampLastSeen(item, runtime)
  if not isProvenOnline(item, runtime) then
    return
  end
  OnlineWatch.StampSeen(runtime, Store.Find(runtime.store, item.conversationKey))
end

function AvailabilityEnricher.EnrichContactsAvailability(contacts, runtime)
  local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
  for _, item in ipairs(contacts) do
    if item.guid and runtime.availabilityByGUID[item.guid] then
      WoWStatus.ApplyCached(item, runtime)
    elseif item.guid and item.channel ~= "BN" then
      WoWStatus.ApplyPresenceFallback(item, runtime)
    end
    if item.guid and item.channel ~= "BN" then
      WoWStatus.ApplyZone(item)
    end
    -- WoW contacts with no availability after all checks: default to Offline
    if item.availability == nil and item.channel ~= "BN" then
      item.availability = Availability.FromStatus("Offline")
    end
    -- BNet contacts: query live status and refresh metadata from BNet API
    if item.channel == "BN" and item.bnetAccountID then
      BNetStatus.Apply(item, runtime)
    end
    stampLastSeen(item, runtime)
  end
end

ns.AvailabilityEnricher = AvailabilityEnricher
return AvailabilityEnricher
