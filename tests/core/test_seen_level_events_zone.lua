require("tests.helpers.fake_ui")
local Identity = require("WhisperMessenger.Model.Identity")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local SeenZone = require("WhisperMessenger.Model.SeenZone")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")

local function fire(event, ...)
  local frame = SeenLevelEvents._frame
  frame:GetScript("OnEvent")(frame, event, ...)
end

local function makeRuntime(results)
  local runtime = {
    localProfileId = "me",
    store = { conversations = {} },
    refreshed = {},
  }
  runtime.friendListApi = {
    GetNumWhoResults = function()
      return #results
    end,
    GetWhoInfo = function(i)
      return results[i]
    end,
  }
  runtime.scheduleIncomingRefresh = function(key)
    runtime.refreshed[#runtime.refreshed + 1] = key
  end
  return runtime
end

local function saveChat(runtime, nameKey, channel)
  local key = Identity.BuildConversationKey(runtime.localProfileId, "WOW::" .. nameKey)
  local conversation = { conversationKey = key, channel = channel or "WOW", characterLevel = 70 }
  runtime.store.conversations[key] = conversation
  return key, conversation
end

return function()
  local realOnWhoListUpdate = WhoLookup.OnWhoListUpdate
  local realRecord = SeenZone.Record
  local realTime = rawget(_G, "time")
  local clock = 100
  local function reset()
    SeenLevelEvents._reset()
    SeenLevel._reset()
    SeenZone._reset()
    clock = 100
    WhoLookup.OnWhoListUpdate = function() end
    rawset(_G, "time", function()
      return clock
    end)
  end
  local function start(results)
    local runtime = makeRuntime(results)
    SeenLevelEvents.Init(runtime)
    return runtime
  end

  -- test_who_list_update_records_zone_with_clock_time
  do
    reset()
    clock = 123
    start({ { fullName = "Bob", level = 70, area = "Stormwind" } })
    fire("WHO_LIST_UPDATE")
    local zone, seenAt = SeenZone.Get("Bob")
    assert(zone == "Stormwind", "who area should be stored as zone")
    assert(seenAt == 123, "seenAt should be the clock time")
  end

  -- test_zone_schedules_refresh_for_saved_chat
  do
    reset()
    local runtime = start({ { fullName = "Bob", level = 70, area = "Stormwind" } })
    local key = saveChat(runtime, "bob")
    fire("WHO_LIST_UPDATE")
    assert(runtime.refreshed[1] == key and #runtime.refreshed == 1, "saved chat should refresh once")
  end

  -- test_zone_without_saved_chat_schedules_nothing
  do
    reset()
    local runtime = start({ { fullName = "Bob", level = 70, area = "Stormwind" } })
    fire("WHO_LIST_UPDATE")
    assert(#runtime.refreshed == 0, "no saved chat means no refresh")
  end

  -- test_zone_for_bnet_chat_schedules_nothing
  do
    reset()
    local runtime = start({ { fullName = "Bob", level = 70, area = "Stormwind" } })
    saveChat(runtime, "bob", "BN")
    fire("WHO_LIST_UPDATE")
    assert(#runtime.refreshed == 0, "BN chat should not refresh")
  end

  -- test_throwing_zone_row_does_not_abort_later_rows
  do
    reset()
    SeenZone.Record = function(name, ...)
      if name == "Bad" then
        error("secret zone")
      end
      return realRecord(name, ...)
    end
    start({
      { fullName = "Bad", level = 10, area = "X" },
      { fullName = "Ann", level = 60, area = "Orgrimmar" },
    })
    fire("WHO_LIST_UPDATE")
    SeenZone.Record = realRecord
    assert(SeenLevel.Get(nil, "Ann") == 60, "later row level should be recorded")
    assert(SeenZone.Get("Ann") == "Orgrimmar", "later row zone should be recorded")
  end

  -- test_unrelated_system_line_keeps_old_zone_time
  do
    reset()
    start({ { fullName = "Bob", level = 70, area = "Stormwind" } })
    SeenZone.Record("Bob", "Stormwind", 1)
    clock = 500
    fire("CHAT_MSG_SYSTEM", "You have been invited")
    local _, seenAt = SeenZone.Get("Bob")
    assert(seenAt == 1, "a line without the name must not re-stamp the zone")
  end

  -- test_system_line_naming_player_stamps_zone
  do
    reset()
    start({ { fullName = "Bob", level = 70, area = "Stormwind" } })
    SeenZone.Record("Bob", "Stormwind", 1)
    clock = 500
    fire("CHAT_MSG_SYSTEM", "|Hplayer:Bob|h[Bob]|h: Level 70 Human Mage <Guild> - Stormwind")
    local _, seenAt = SeenZone.Get("Bob")
    assert(seenAt == 500, "a who row naming the player should stamp the zone")
  end

  -- test_system_line_matches_short_name_of_cross_realm_player
  do
    reset()
    start({ { fullName = "Bob-Draenor", level = 70, area = "Stormwind" } })
    clock = 500
    fire("CHAT_MSG_SYSTEM", "|Hplayer:Bob-Draenor|h[Bob-Draenor]|h: Level 70 Human Mage - Stormwind")
    local _, seenAt = SeenZone.Get("Bob-Draenor")
    assert(seenAt == 500, "realm suffix should not block the name match")
  end

  -- test_online_line_naming_player_does_not_restamp_zone
  do
    reset()
    start({ { fullName = "Bob", level = 70, area = "Stormwind" } })
    SeenZone.Record("Bob", "Stormwind", 100)
    clock = 500
    fire("CHAT_MSG_SYSTEM", "|Hplayer:Bob|h[Bob]|h has come online.")
    local _, seenAt = SeenZone.Get("Bob")
    assert(seenAt == 100, "a non-who line naming the player must not re-stamp the zone")
  end

  -- test_row_for_longer_name_does_not_restamp_prefix_name
  do
    reset()
    start({ { fullName = "Al", level = 70, area = "Stormwind" } })
    SeenZone.Record("Al", "Stormwind", 100)
    clock = 500
    fire("CHAT_MSG_SYSTEM", "|Hplayer:Alice|h[Alice]|h: Level 70 Human Mage - Stormwind")
    local _, seenAt = SeenZone.Get("Al")
    assert(seenAt == 100, "a row for Alice must not re-stamp Al")
  end

  -- test_row_with_other_area_does_not_restamp_zone
  do
    reset()
    start({ { fullName = "Bob", level = 70, area = "Stormwind" } })
    SeenZone.Record("Bob", "Stormwind", 100)
    clock = 500
    fire("CHAT_MSG_SYSTEM", "|Hplayer:Bob|h[Bob]|h: Level 70 Human Mage - Orgrimmar")
    local _, seenAt = SeenZone.Get("Bob")
    assert(seenAt == 100, "a row without the recorded area must not re-stamp the zone")
  end

  -- test_non_string_system_text_records_no_zone
  do
    reset()
    start({ { fullName = "Bob", level = 70, area = "Stormwind" } })
    fire("CHAT_MSG_SYSTEM", 42)
    assert(SeenZone.Get("Bob") == nil, "non-string system text must not record a zone")
  end

  WhoLookup.OnWhoListUpdate = realOnWhoListUpdate
  SeenZone.Record = realRecord
  rawset(_G, "time", realTime)
  SeenLevelEvents._reset()
  SeenLevel._reset()
  SeenZone._reset()
end
