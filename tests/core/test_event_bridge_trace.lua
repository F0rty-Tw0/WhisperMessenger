local traceEnabled = false
local traceCalls = 0
local mockTrace = setmetatable({}, {
  __call = function()
    traceCalls = traceCalls + 1
  end,
})

function mockTrace.isEnabled()
  return traceEnabled
end

package.loaded["WhisperMessenger.Core.Trace"] = mockTrace
package.loaded["Core.Trace"] = mockTrace
package.loaded["WhisperMessenger.Core.EventRouter"] = {
  HandleEvent = function()
    return nil
  end,
}
package.loaded["Core.EventRouter"] = package.loaded["WhisperMessenger.Core.EventRouter"]
package.loaded["WhisperMessenger.Core.Bootstrap.EventBridge"] = nil
local Store = require("WhisperMessenger.Model.ConversationStore")

package.loaded["Core.Bootstrap.EventBridge"] = nil

local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

return function()
  local conversions = 0
  local value = setmetatable({}, {
    __tostring = function()
      conversions = conversions + 1
      return "secret-safe-value"
    end,
  })

  EventBridge.RouteLiveEvent({}, function() end, "CHAT_MSG_WHISPER", "text", value)
  assert(conversions == 0, "disabled trace must not format payload values")
  assert(traceCalls == 0, "disabled trace must not invoke trace")

  traceEnabled = true
  EventBridge.RouteLiveEvent({}, function() end, "CHAT_MSG_WHISPER", "text", value)
  assert(conversions == 1, "enabled trace should format inside its protected trace path")
  assert(traceCalls == 2, "enabled trace should emit payload and result lines")

  local groupRuntime = {
    localProfileId = "me",
    store = Store.New(),
    availabilityByGUID = {},
  }
  traceEnabled = false
  EventBridge.RouteGroupEvent(groupRuntime, "CHAT_MSG_PARTY", "text", value)
  assert(conversions == 1, "disabled group trace must not format payload values")
  assert(traceCalls == 2, "disabled group trace must not invoke trace")

  traceEnabled = true
  EventBridge.RouteGroupEvent(groupRuntime, "CHAT_MSG_PARTY", "text", value)
  assert(conversions == 2, "enabled group trace should format inside its protected trace path")
  assert(traceCalls == 3, "enabled group trace should emit one trace line")
end
