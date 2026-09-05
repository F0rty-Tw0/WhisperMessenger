local typingMeta = { presence = "typing", typingActive = true }
package.loaded["WhisperMessenger.Core.EventRouter"] = {
  HandleEvent = function()
    return { conversationKey = "k1" }, typingMeta
  end,
}
package.loaded["Core.EventRouter"] = package.loaded["WhisperMessenger.Core.EventRouter"]
package.loaded["WhisperMessenger.Core.Bootstrap.EventBridge"] = nil
package.loaded["Core.Bootstrap.EventBridge"] = nil

local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local LivePresence = require("WhisperMessenger.Model.LivePresence")

return function()
  local savedTimer = _G.C_Timer
  local scheduled = {}
  _G.C_Timer = {
    After = function(delay, fn)
      table.insert(scheduled, { delay = delay, fn = fn })
    end,
  }
  local refreshed = {}
  local function refreshWindow(key)
    table.insert(refreshed, key)
  end
  local runtime = { accountState = { settings = {} } }

  -- test_typing_start_schedules_expiry_refresh
  EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|1", "WHISPER", "Arthas")
  assert(#refreshed == 1 and refreshed[1] == "k1", "immediate refresh for the typing conversation")
  assert(#scheduled == 1, "one expiry timer scheduled")
  assert(scheduled[1].delay >= LivePresence.TYPING_TTL, "expiry fires after the ttl")
  scheduled[1].fn()
  assert(#refreshed == 2 and refreshed[2] == "k1", "expiry refreshes the same conversation")

  -- test_typing_stop_schedules_nothing
  typingMeta.typingActive = false
  EventBridge.RouteLiveEvent(runtime, refreshWindow, "CHAT_MSG_ADDON", "WMRX", "1|T|0", "WHISPER", "Arthas")
  assert(#scheduled == 1, "stop does not schedule a timer")

  _G.C_Timer = savedTimer
end
