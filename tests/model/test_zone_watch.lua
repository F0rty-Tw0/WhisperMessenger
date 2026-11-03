local ZoneWatch = require("WhisperMessenger.Model.ZoneWatch")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

-- "Notify when they change zone": one-shot per contact. The first known zone
-- is the baseline; the first different zone fires once and disarms.
return function()
  -- test_unarmed_contact_never_fires
  do
    local conversation = {}
    assert(ZoneWatch.Observe(conversation, "Stormwind City") == nil, "not armed: no alert")
    assert(conversation.notifyZoneFrom == nil, "not armed: no baseline stored")
  end

  -- test_first_known_zone_is_the_baseline
  do
    local conversation = { notifyZone = true }
    assert(ZoneWatch.Observe(conversation, "Stormwind City") == nil, "baseline: no alert")
    assert(conversation.notifyZoneFrom == "Stormwind City", "baseline recorded")
    assert(ZoneWatch.Observe(conversation, "Stormwind City") == nil, "same zone: no alert")
  end

  -- test_unknown_zone_waits_for_the_first_known_one
  do
    local conversation = { notifyZone = true }
    assert(ZoneWatch.Observe(conversation, nil) == nil, "unknown zone: no alert")
    assert(ZoneWatch.Observe(conversation, "") == nil, "empty zone: no alert")
    assert(conversation.notifyZoneFrom == nil and conversation.notifyZone == true, "still waiting, still armed")
    assert(ZoneWatch.Observe(conversation, "Orgrimmar") == nil, "first known zone is only the baseline")
    assert(conversation.notifyZoneFrom == "Orgrimmar", "baseline taken from the first known zone")
  end

  -- test_zone_change_fires_once_and_disarms
  do
    local conversation = { notifyZone = true, notifyZoneFrom = "Stormwind City" }
    local from, to = ZoneWatch.Observe(conversation, "Elwynn Forest")
    assert(from == "Stormwind City" and to == "Elwynn Forest", "reports old and new zone")
    assert(conversation.notifyZone == nil and conversation.notifyZoneFrom == nil, "disarmed after firing")
    assert(ZoneWatch.Observe(conversation, "Westfall") == nil, "one-shot: no second alert")
  end

  -- test_offline_keeps_it_armed
  do
    local conversation = { notifyZone = true, notifyZoneFrom = "Stormwind City" }
    assert(ZoneWatch.Observe(conversation, nil) == nil, "offline: no alert")
    assert(conversation.notifyZone == true and conversation.notifyZoneFrom == "Stormwind City", "offline keeps arm and baseline")
  end

  -- test_secret_zone_is_skipped
  do
    local savedSecret = _G.issecretvalue
    local secret = "SecretZone"
    rawset(_G, "issecretvalue", function(value)
      return value == secret
    end)
    local conversation = { notifyZone = true, notifyZoneFrom = "Stormwind City" }
    assert(ZoneWatch.Observe(conversation, secret) == nil, "secret zone: no alert")
    assert(conversation.notifyZone == true and conversation.notifyZoneFrom == "Stormwind City", "secret zone changes nothing")
    local fresh = { notifyZone = true }
    ZoneWatch.Observe(fresh, secret)
    assert(fresh.notifyZoneFrom == nil, "secret zone never becomes the baseline")
    rawset(_G, "issecretvalue", savedSecret)
  end

  -- test_can_watch_only_where_zone_is_visible
  do
    PresenceCache._reset()
    PresenceCache._setCache({ ["Player-GUILD"] = "offline" })
    assert(ZoneWatch.CanWatch({ channel = "BN", areaName = "Dornogal" }) == true, "Battle.net friend in WoW")
    assert(ZoneWatch.CanWatch({ channel = "BN" }) == false, "Battle.net friend outside WoW")
    assert(ZoneWatch.CanWatch({ channel = "WOW", guid = "Player-GUILD" }) == true, "guild member, even offline")
    assert(ZoneWatch.CanWatch({ channel = "WOW", guid = "Player-X" }) == false, "stranger")
    assert(ZoneWatch.CanWatch({ channel = "WOW", guid = "Player-X", notifyZone = true }) == true, "armed: shown so it can be turned off")
    assert(ZoneWatch.CanWatch(nil) == false, "no item")
    PresenceCache._reset()
  end
end
