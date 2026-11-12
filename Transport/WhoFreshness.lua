local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")
local SeenZone = ns.SeenZone or require("WhisperMessenger.Model.SeenZone")

-- Is a player's level, zone and guild recent enough that WhoLookup need not
-- ask again? Fresh when any clause holds; each reads its own clock, never
-- mixed:
-- (a) the contact is online with a live presence zone (no clock),
-- (b) we asked within STALE_SECONDS (askedAt and nowValue share GetTime),
-- (c) a /who answer for the name landed within STALE_SECONDS (time()).
local WhoFreshness = {}

WhoFreshness.STALE_SECONDS = 600

function WhoFreshness.IsFresh(conversation, name, askedAt, nowValue)
  local guid = conversation.guid
  if guid and PresenceCache.GetPresence(guid) == "online" then
    local zone = PresenceCache.GetZone(guid)
    if type(zone) == "string" and zone ~= "" then
      return true
    end
  end
  if askedAt and nowValue - askedAt < WhoFreshness.STALE_SECONDS then
    return true
  end
  local _, seenAt = SeenZone.Get(name)
  return type(seenAt) == "number" and _G.time() - seenAt < WhoFreshness.STALE_SECONDS
end

ns.WhoFreshness = WhoFreshness

return WhoFreshness
