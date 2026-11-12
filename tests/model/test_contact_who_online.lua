local AvailabilityEnricher = require("WhisperMessenger.Model.ContactEnricher.AvailabilityEnricher")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local SeenZone = require("WhisperMessenger.Model.SeenZone")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local WhoFreshness = require("WhisperMessenger.Transport.WhoFreshness")
local Availability = require("WhisperMessenger.Transport.Availability")

-- A /who answer proves a WoW chat's player was online when it landed.
local NOW = 100000

local function enrich(item, availabilityByGUID)
  AvailabilityEnricher.EnrichContactsAvailability({ item }, { availabilityByGUID = availabilityByGUID or {}, store = { conversations = {} } })
  return item
end

local function answeredAgo(seconds, fields, availabilityByGUID)
  PresenceCache._reset()
  SeenZone._reset()
  SeenZone.Record("Someone", "Stormwind", NOW - seconds)
  local item = { channel = "WOW", displayName = "Someone" }
  for field, value in pairs(fields or {}) do
    item[field] = value
  end
  return enrich(item, availabilityByGUID)
end

local function status(item)
  return item.availability and item.availability.status
end

return function()
  local savedTime = rawget(_G, "time")
  rawset(_G, "time", function()
    return NOW
  end)
  DisplayName.Configure({ showPlayerLevels = true })

  -- test_fresh_who_answer_shows_online
  do
    local item = answeredAgo(0)
    assert(status(item) == "CanWhisper", "a fresh /who answer should show Online, got " .. tostring(status(item)))
  end

  -- test_who_answer_just_under_limit_shows_online
  do
    local item = answeredAgo(WhoFreshness.STALE_SECONDS - 1)
    assert(status(item) == "CanWhisper", "599 s should still be Online, got " .. tostring(status(item)))
  end

  -- test_who_answer_at_limit_falls_back_to_offline
  do
    local item = answeredAgo(WhoFreshness.STALE_SECONDS)
    assert(status(item) == "Offline", "600 s is no longer Online, got " .. tostring(status(item)))
  end

  -- test_no_who_answer_stays_offline
  do
    PresenceCache._reset()
    SeenZone._reset()
    local item = enrich({ channel = "WOW", displayName = "Someone" })
    assert(status(item) == "Offline", "no answer means the Offline default, got " .. tostring(status(item)))
  end

  -- test_guid_chat_without_check_shown_online_by_who
  do
    local item = answeredAgo(0, { guid = "Player-1-AAA" })
    assert(status(item) == "CanWhisper", "a fresh /who beats a guid chat's default Offline, got " .. tostring(status(item)))
  end

  -- test_guid_chat_cached_offline_shown_online_by_who
  do
    local item = answeredAgo(0, { guid = "Player-1-AAA" }, { ["Player-1-AAA"] = Availability.FromStatus("Offline") })
    assert(status(item) == "CanWhisper", "a fresh /who beats the game's Offline check, got " .. tostring(status(item)))
  end

  -- test_guid_chat_stale_who_keeps_cached_offline
  do
    local cached = { ["Player-1-AAA"] = Availability.FromStatus("Offline") }
    local item = answeredAgo(WhoFreshness.STALE_SECONDS, { guid = "Player-1-AAA" }, cached)
    assert(status(item) == "Offline", "a stale /who leaves the game's Offline, got " .. tostring(status(item)))
  end

  -- test_guid_chat_cached_busy_kept_over_who
  do
    local item = answeredAgo(0, { guid = "Player-1-AAA" }, { ["Player-1-AAA"] = Availability.FromStatus("Busy") })
    assert(status(item) == "Busy", "/who only replaces Offline, got " .. tostring(status(item)))
  end

  -- test_levels_option_off_no_online
  do
    DisplayName.Configure({ showPlayerLevels = false })
    local item = answeredAgo(0)
    assert(status(item) == "Offline", "with player levels off a /who answer shows nothing, got " .. tostring(status(item)))
    DisplayName.Configure({ showPlayerLevels = true })
  end

  -- test_group_chat_not_marked_online
  do
    local item = answeredAgo(0, { channel = "PARTY" })
    assert(status(item) ~= "CanWhisper", "only whisper chats take a /who answer")
  end

  rawset(_G, "time", savedTime)
  PresenceCache._reset()
  SeenZone._reset()
  DisplayName.Configure({ showPlayerLevels = false })
end
