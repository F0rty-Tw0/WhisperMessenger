local Store = require("WhisperMessenger.Model.ConversationStore")
local LivePresence = require("WhisperMessenger.Model.LivePresence")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

local KEY = "wow::WOW::arthas-area52"

local function newHarness()
  local now = 100
  local scheduled, refreshed = {}, {}
  local runtime = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    accountState = { settings = {} },
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return now
    end,
  }
  runtime.store.conversations[KEY] = {
    channel = "WOW",
    displayName = "Arthas-Area52",
    messages = { { direction = "out", kind = "user", wireId = "out1", text = "hello", sentAt = 90 } },
  }
  _G.C_Timer = {
    After = function(delay, callback)
      scheduled[#scheduled + 1] = { at = now + delay, callback = callback }
    end,
  }
  local function refresh(key)
    refreshed[#refreshed + 1] = key
  end
  local function receive(payload)
    EventBridge.RouteLiveEvent(runtime, refresh, "CHAT_MSG_ADDON", "WMRX", payload, "WHISPER", "Arthas-Area52")
  end
  local function advance(seconds)
    now = now + seconds
    local pending = scheduled
    scheduled = {}
    for _, timer in ipairs(pending) do
      if timer.at <= now then
        timer.callback()
      else
        scheduled[#scheduled + 1] = timer
      end
    end
  end
  return runtime, refreshed, receive, advance
end

return function()
  local savedTimer = _G.C_Timer

  -- test_stopped_typing_does_not_redraw_again_at_expiry
  do
    local runtime, refreshed, receive, advance = newHarness()
    receive("1|T|1")
    receive("1|T|0")
    assert(not LivePresence.IsTyping(runtime, KEY, runtime.now()), "stop clears the indicator")
    assert(#refreshed == 2, "start and stop are visible transitions")
    advance(7)
    assert(#refreshed == 2, "expiry after an explicit stop must not redraw the window again")
  end

  -- test_restarted_typing_expires_once_at_the_new_deadline
  do
    local runtime, refreshed, receive, advance = newHarness()
    receive("1|T|1")
    advance(1)
    receive("1|T|0")
    advance(1)
    receive("1|T|1")
    advance(5)
    assert(LivePresence.IsTyping(runtime, KEY, runtime.now()), "old deadline cannot clear restarted typing")
    assert(#refreshed == 3, "old deadline does not redraw the restarted indicator")
    advance(2)
    assert(not LivePresence.IsTyping(runtime, KEY, runtime.now()), "new deadline expires typing")
    assert(#refreshed == 4, "restarted indicator refreshes exactly once on expiry")
  end

  -- test_duplicate_and_unknown_receipts_do_not_redraw
  do
    local runtime, refreshed, receive = newHarness()
    receive("1|S|out1")
    assert(runtime.store.conversations[KEY].messages[1].seenAt == 100, "receipt marks the outgoing message seen")
    assert(#refreshed == 1, "new receipt refreshes the seen label")
    for _ = 1, 10 do
      receive("1|S|out1")
      receive("1|S|unknown")
    end
    assert(#refreshed == 1, "unchanged receipts must not rebuild contacts and transcript")
  end

  _G.C_Timer = savedTimer
end
