local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")
local Localization = require("WhisperMessenger.Locale.Localization")

-- Offline contacts keep "Offline" and add when they were last around:
-- Battle.net friends from Blizzard's last-online time, character contacts
-- from our own last-seen timestamp.
local OFFLINE = { status = "Offline" }
local ONLINE = { status = "CanWhisper" }

return function()
  Localization.Configure({ language = "enUS" })
  rawset(_G, "time", rawget(_G, "time") or os.time)
  rawset(_G, "date", rawget(_G, "date") or os.date)
  local now = os.time()

  -- test_bnet_offline_shows_last_online
  do
    local _, line2 = StatusLine.Build({ channel = "BN", lastOnlineTime = now - 120 }, OFFLINE)
    assert(line2 == "Offline  -  Last online 2m", "got " .. tostring(line2))
  end

  -- test_character_offline_shows_last_seen
  do
    local contact = { channel = "WOW", conversation = { lastSeenAt = now - 3 * 3600 } }
    local _, line2 = StatusLine.Build(contact, OFFLINE)
    assert(line2 == "Offline  -  Last seen 3h", "got " .. tostring(line2))
  end

  -- test_last_incoming_whisper_counts_as_seen
  do
    local contact = { channel = "WOW", conversation = { lastSeenAt = now - 3 * 3600, lastIncomingAt = now - 300 } }
    local _, line2 = StatusLine.Build(contact, OFFLINE)
    assert(line2 == "Offline  -  Last seen 5m", "the newer incoming whisper wins, got " .. tostring(line2))
  end

  -- test_unknown_time_stays_offline
  do
    local _, line2 = StatusLine.Build({ channel = "WOW", conversation = {} }, OFFLINE)
    assert(line2 == "Offline", "no timestamp: plain Offline, got " .. tostring(line2))
  end

  -- test_online_contact_is_unchanged
  do
    local _, line2 = StatusLine.Build({ channel = "WOW", conversation = { lastSeenAt = now - 60 } }, ONLINE)
    assert(line2 == "Online", "online keeps its label, got " .. tostring(line2))
  end

  -- test_translated_label
  do
    Localization.Configure({ language = "deDE" })
    local _, line2 = StatusLine.Build({ channel = "BN", lastOnlineTime = now - 120 }, OFFLINE)
    assert(line2 ~= "Last online 2m" and string.find(line2, "2", 1, true), "label translated, got " .. tostring(line2))
    Localization.Configure({ language = "enUS" })
  end
end
