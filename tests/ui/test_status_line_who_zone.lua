local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")
local Localization = require("WhisperMessenger.Locale.Localization")

local ONLINE = { status = "CanWhisper" }
local OFFLINE = { status = "Offline" }

return function()
  Localization.Configure({ language = "enUS" })
  rawset(_G, "time", rawget(_G, "time") or os.time)
  rawset(_G, "date", rawget(_G, "date") or os.date)
  local now = os.time()

  -- test_who_zone_shows_with_age
  do
    local contact = { channel = "WOW", whoArea = "Stormwind", whoAreaAt = now - 300 }
    local _, line2 = StatusLine.Build(contact, ONLINE)
    assert(line2:find("Stormwind (5m)", 1, true), "got " .. tostring(line2))
  end

  -- test_live_zone_hides_who_zone
  do
    local contact = { channel = "WOW", areaName = "Elwynn", whoArea = "Stormwind", whoAreaAt = now - 300 }
    local _, line2 = StatusLine.Build(contact, ONLINE)
    assert(line2:find("Elwynn", 1, true), "got " .. tostring(line2))
    assert(not line2:find("Stormwind", 1, true), "got " .. tostring(line2))
  end

  -- test_offline_with_guid_hides_who_zone
  do
    local contact = { channel = "WOW", guid = "Player-1-AAA", whoArea = "Stormwind", whoAreaAt = now - 300 }
    local _, line2 = StatusLine.Build(contact, OFFLINE)
    assert(not line2:find("Stormwind", 1, true), "got " .. tostring(line2))
  end

  -- test_offline_without_guid_keeps_who_zone
  do
    local contact = { channel = "WOW", whoArea = "Stormwind", whoAreaAt = now - 300 }
    local _, line2 = StatusLine.Build(contact, OFFLINE)
    assert(line2:find("Stormwind (", 1, true), "got " .. tostring(line2))
  end

  -- test_offline_without_guid_with_who_zone_drops_offline_and_last_seen
  do
    local contact = {
      channel = "WOW",
      whoArea = "Stormwind",
      whoAreaAt = now,
      conversation = { lastSeenAt = now - 7200 },
    }
    local _, line2 = StatusLine.Build(contact, OFFLINE)
    assert(line2 == "Stormwind (now)", "got " .. tostring(line2))
  end

  -- test_offline_without_guid_without_who_zone_keeps_offline
  do
    local contact = { channel = "WOW", conversation = { lastSeenAt = now - 7200 } }
    local _, line2 = StatusLine.Build(contact, OFFLINE)
    assert(line2:find("Offline", 1, true), "got " .. tostring(line2))
    assert(line2:find("Last seen", 1, true), "got " .. tostring(line2))
  end
end
