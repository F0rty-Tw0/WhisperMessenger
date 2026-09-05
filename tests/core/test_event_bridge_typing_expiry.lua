local stubResult = { conversationKey = "k1" }
local typingMeta = { presence = "typing", typingActive = true }
package.loaded["WhisperMessenger.Core.EventRouter"] = {
  HandleEvent = function()
    return stubResult, typingMeta
  end,
}
package.loaded["Core.EventRouter"] = package.loaded["WhisperMessenger.Core.EventRouter"]
package.loaded["WhisperMessenger.Core.Bootstrap.EventBridge"] = nil
package.loaded["Core.Bootstrap.EventBridge"] = nil

local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local LivePresence = require("WhisperMessenger.Model.LivePresence")

local function newHarness()
  local scheduled = {}
  local refreshed = {}
  _G.C_Timer = {
    After = function(delay, fn)
      table.insert(scheduled, { delay = delay, fn = fn })
    end,
  }
  local function refreshWindow(key)
    table.insert(refreshed, key)
  end
  return scheduled, refreshed, refreshWindow
end

local function newRuntime(nowRef)
  return {
    accountState = { settings = {} },
    now = function()
      return nowRef and nowRef.value or 0
    end,
  }
end

return function()
  local savedTimer = _G.C_Timer

  -- test_typing_start_schedules_expiry_refresh
  do
    local scheduled, refreshed, refreshWindow = newHarness()
    local runtime = newRuntime()
    typingMeta.typingActive = true
    typingMeta.typingChanged = nil
    EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|1", "WHISPER", "Arthas")
    assert(#refreshed == 1 and refreshed[1] == "k1", "immediate refresh for the typing conversation")
    assert(#scheduled == 1, "one expiry timer scheduled")
    assert(scheduled[1].delay >= LivePresence.TYPING_TTL, "expiry fires after the ttl")
    scheduled[1].fn()
    assert(#refreshed == 2 and refreshed[2] == "k1", "expiry refreshes the same conversation")
  end

  -- test_typing_stop_schedules_nothing
  do
    local scheduled, _, refreshWindow = newHarness()
    local runtime = newRuntime()
    typingMeta.typingActive = false
    typingMeta.typingChanged = nil
    EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|0", "WHISPER", "Arthas")
    assert(#scheduled == 0, "stop does not schedule a timer")
  end

  -- test_repeat_typing_packet_does_not_refresh
  do
    local _, refreshed, refreshWindow = newHarness()
    local runtime = newRuntime()
    typingMeta.typingActive = true
    typingMeta.typingChanged = false
    EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|1", "WHISPER", "Arthas")
    assert(#refreshed == 0, "repeat packet inside ttl does not refresh")
  end

  -- test_only_one_expiry_timer_per_conversation
  do
    local scheduled, _, refreshWindow = newHarness()
    local runtime = newRuntime()
    typingMeta.typingActive = true
    typingMeta.typingChanged = true
    EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|1", "WHISPER", "Arthas")
    typingMeta.typingChanged = false
    EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|1", "WHISPER", "Arthas")
    EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|1", "WHISPER", "Arthas")
    assert(#scheduled == 1, "only one expiry timer pending per conversation")
  end

  -- test_expiry_timer_rearms_while_peer_still_typing
  do
    local scheduled, refreshed, refreshWindow = newHarness()
    local nowRef = { value = 0 }
    local runtime = newRuntime(nowRef)
    typingMeta.typingActive = true
    typingMeta.typingChanged = true
    EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|1", "WHISPER", "Arthas")
    assert(#scheduled == 1, "expiry timer scheduled")

    -- peer sends another keystroke at t=3, extending typing to expire at 3+TTL
    LivePresence.SetTyping(runtime, "k1", true, 3)
    nowRef.value = 6
    local refreshedBeforeFire = #refreshed
    scheduled[1].fn()
    assert(#refreshed == refreshedBeforeFire, "no refresh while peer still typing")
    assert(#scheduled == 2, "timer re-armed")
    assert(math.abs(scheduled[2].delay - 3.2) < 0.001, "re-armed with remaining time plus grace")
  end

  -- test_expiry_timer_refreshes_and_clears_pending_after_ttl
  do
    local scheduled, refreshed, refreshWindow = newHarness()
    local nowRef = { value = 0 }
    local runtime = newRuntime(nowRef)
    typingMeta.typingActive = true
    typingMeta.typingChanged = true
    EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|1", "WHISPER", "Arthas")
    LivePresence.SetTyping(runtime, "k1", true, 0)
    nowRef.value = 10
    local refreshedBeforeFire = #refreshed
    scheduled[1].fn()
    assert(#refreshed == refreshedBeforeFire + 1, "expiry refreshes once after ttl elapses")
    assert(runtime.typingExpiryPending["k1"] == nil, "pending cleared after firing")

    typingMeta.typingChanged = true
    EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|1", "WHISPER", "Arthas")
    assert(#scheduled == 2, "new typing packet schedules a fresh timer")
  end

  _G.C_Timer = savedTimer
end
