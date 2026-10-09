require("tests.helpers.fake_ui")
local Identity = require("WhisperMessenger.Model.Identity")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")

local WHO_EVENTS = { "WHO_LIST_UPDATE", "CHAT_MSG_SYSTEM" }

local function fire(event, ...)
  local frame = SeenLevelEvents._frame
  frame:GetScript("OnEvent")(frame, event, ...)
end

local function isRegistered(event)
  return SeenLevelEvents._frame:IsEventRegistered(event)
end

local function assertWhoEvents(expected, label)
  for _, event in ipairs(WHO_EVENTS) do
    assert(isRegistered(event) == expected, event .. " " .. label)
  end
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

local function saveChat(runtime, nameKey)
  local key = Identity.BuildConversationKey(runtime.localProfileId, "WOW::" .. nameKey)
  local conversation = { conversationKey = key, channel = "WOW" }
  runtime.store.conversations[key] = conversation
  return key, conversation
end

return function()
  local savedSuspended = rawget(_G, "_wmSuspended")
  local realOnWhoListUpdate = WhoLookup.OnWhoListUpdate
  local whoUpdates = 0
  local function reset()
    rawset(_G, "_wmSuspended", nil)
    SeenLevelEvents._reset()
    SeenLevel._reset()
    whoUpdates = 0
    WhoLookup.OnWhoListUpdate = function()
      whoUpdates = whoUpdates + 1
    end
  end

  -- test_set_enabled_true_leaves_who_events_unregistered
  do
    reset()
    SeenLevelEvents.Init(makeRuntime({}))
    SeenLevelEvents.SetEnabled(true)
    assertWhoEvents(false, "should stay unregistered outside the who window")
  end

  -- test_open_who_window_registers_who_events
  do
    reset()
    SeenLevelEvents.Init(makeRuntime({}))
    SeenLevelEvents.SetEnabled(true)
    SeenLevelEvents.OpenWhoWindow()
    assertWhoEvents(true, "should be registered inside the who window")
  end

  -- test_close_who_window_unregisters_who_events
  do
    reset()
    SeenLevelEvents.Init(makeRuntime({}))
    SeenLevelEvents.SetEnabled(true)
    SeenLevelEvents.OpenWhoWindow()
    SeenLevelEvents.CloseWhoWindow()
    assertWhoEvents(false, "should be unregistered after the who window closes")
    assert(isRegistered("PLAYER_TARGET_CHANGED"), "closing the who window keeps unit events")
  end

  -- test_open_who_window_while_disabled_registers_nothing
  do
    reset()
    SeenLevelEvents.Init(makeRuntime({}))
    SeenLevelEvents.OpenWhoWindow()
    assertWhoEvents(false, "should stay unregistered while recording is off")
  end

  -- test_open_who_window_while_suspended_registers_nothing
  do
    reset()
    rawset(_G, "_wmSuspended", true)
    SeenLevelEvents.Init(makeRuntime({}))
    SeenLevelEvents.SetEnabled(true)
    SeenLevelEvents.OpenWhoWindow()
    assertWhoEvents(false, "should stay unregistered while suspended")
  end

  -- test_set_enabled_false_with_window_open_unregisters_all_eight_events
  do
    reset()
    SeenLevelEvents.Init(makeRuntime({}))
    SeenLevelEvents.SetEnabled(true)
    SeenLevelEvents.OpenWhoWindow()
    SeenLevelEvents.SetEnabled(false)
    for _, event in ipairs(SeenLevelEvents.UNIT_EVENTS) do
      assert(not isRegistered(event), event .. " should be unregistered")
    end
    assertWhoEvents(false, "should be unregistered when recording turns off")
    SeenLevelEvents.OpenWhoWindow()
    assertWhoEvents(false, "a later who window should not register while off")
  end

  -- test_re_enable_inside_who_window_registers_who_events
  do
    reset()
    local realIsWindowOpen = WhoLookup.IsWindowOpen
    WhoLookup.IsWindowOpen = function()
      return true
    end
    SeenLevelEvents.Init(makeRuntime({}))
    SeenLevelEvents.SetEnabled(false)
    SeenLevelEvents.SetEnabled(true)
    WhoLookup.IsWindowOpen = realIsWindowOpen
    assertWhoEvents(true, "should be registered when recording turns on inside the who window")
  end

  -- test_who_list_update_records_and_pushes_result
  do
    reset()
    local runtime = makeRuntime({ { fullName = "Diaperspin", level = 8 } })
    local key, conversation = saveChat(runtime, "diaperspin")
    SeenLevelEvents.Init(runtime)
    fire("WHO_LIST_UPDATE")
    assert(SeenLevel.Get(nil, "Diaperspin") == 8, "who result level should be recorded")
    assert(conversation.characterLevel == 8, "saved chat should get level 8")
    assert(runtime.refreshed[1] == key, "refresh should be scheduled for the chat")
    assert(whoUpdates == 1, "WHO_LIST_UPDATE should end the who query once")
  end

  -- test_chat_msg_system_records_without_ending_who_query
  do
    reset()
    SeenLevelEvents.Init(makeRuntime({ { fullName = "Diaperspin", level = 8 } }))
    fire("CHAT_MSG_SYSTEM", "Diaperspin: Level 8 Gnome Mage - Dun Morogh")
    assert(SeenLevel.Get(nil, "Diaperspin") == 8, "system-line who result should be recorded")
    assert(whoUpdates == 0, "a system line must not end the who query")
  end

  -- test_who_read_error_still_ends_who_query
  do
    reset()
    local runtime = makeRuntime({})
    runtime.friendListApi.GetWhoInfo = function()
      error("secret value")
    end
    runtime.friendListApi.GetNumWhoResults = function()
      return 1
    end
    SeenLevelEvents.Init(runtime)
    local ok = pcall(fire, "WHO_LIST_UPDATE")
    assert(ok, "a throwing who API must not escape the event handler")
    assert(whoUpdates == 1, "the who query should still end after a failed read")
  end

  -- test_who_list_update_without_who_api_still_ends_query
  do
    reset()
    local runtime = makeRuntime({})
    runtime.friendListApi = {}
    SeenLevelEvents.Init(runtime)
    fire("WHO_LIST_UPDATE")
    assert(whoUpdates == 1, "a missing who API should still end the query")
  end

  -- test_who_list_update_in_mythic_lockdown_reads_nothing
  do
    reset()
    local reads = 0
    local runtime = makeRuntime({ { fullName = "Diaperspin", level = 8 } })
    runtime.friendListApi.GetNumWhoResults = function()
      reads = reads + 1
      return 1
    end
    runtime.isMythicLockdown = function()
      return true
    end
    SeenLevelEvents.Init(runtime)
    fire("WHO_LIST_UPDATE")
    assert(reads == 0, "no who API should run in mythic lockdown")
    assert(whoUpdates == 1, "the who query should still end in mythic lockdown")
  end

  WhoLookup.OnWhoListUpdate = realOnWhoListUpdate
  rawset(_G, "_wmSuspended", savedSuspended)
  SeenLevelEvents._reset()
  SeenLevel._reset()
end
