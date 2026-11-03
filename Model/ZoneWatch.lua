local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")

-- "Notify when they change zone": a one-shot per contact, saved on the
-- conversation record like "Notify when online". notifyZone arms it;
-- notifyZoneFrom is the zone seen when it was armed (or the first zone known
-- after that). The first different zone name fires once and disarms.
local ZoneWatch = {}

-- A usable zone name, or nil. A 12.0 secret zone is never compared or stored.
function ZoneWatch.ReadZone(zone)
  if SecretValue.Is(zone) or type(zone) ~= "string" or zone == "" then
    return nil
  end
  return zone
end

-- Returns oldZone, newZone when an armed contact changed zone (and disarms
-- it); nil otherwise. An unknown zone (offline, outside WoW, secret) keeps it
-- armed and the baseline untouched.
function ZoneWatch.Observe(conversation, rawZone)
  if type(conversation) ~= "table" or conversation.notifyZone ~= true then
    return nil
  end
  local zone = ZoneWatch.ReadZone(rawZone)
  if zone == nil then
    return nil
  end
  local from = conversation.notifyZoneFrom
  if from == nil then
    conversation.notifyZoneFrom = zone
    return nil
  end
  if from == zone then
    return nil
  end
  conversation.notifyZone = nil
  conversation.notifyZoneFrom = nil
  return from, zone
end

-- Menu visibility: WoW shows a zone only for Battle.net friends in WoW and
-- guild/community members. An armed contact always shows the entry so it can
-- be turned off.
function ZoneWatch.CanWatch(item)
  if type(item) ~= "table" then
    return false
  end
  if item.notifyZone == true or ZoneWatch.ReadZone(item.areaName) ~= nil then
    return true
  end
  return item.channel ~= "BN" and item.guid ~= nil and PresenceCache.GetPresence(item.guid) ~= nil
end

ns.ZoneWatch = ZoneWatch
return ZoneWatch
