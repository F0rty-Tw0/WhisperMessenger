local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local Constants = require("WhisperMessenger.Core.Constants")

local function bootstrapCountingSyncs()
  local counter = { syncs = 0 }
  counter.Bootstrap = {
    runtime = {
      syncReplyKey = function()
        counter.syncs = counter.syncs + 1
      end,
    },
  }
  return counter
end

return function()
  -- test_house_editor_mode_change_resyncs_reply_key

  -- Opening or closing the house editor must re-run the reply-key sync so R
  -- is handed to housing's "remove decor" binding and taken back afterwards.
  do
    local counter = bootstrapCountingSyncs()

    local handled = LifecycleHandlers.Handle(counter.Bootstrap, "HOUSE_EDITOR_MODE_CHANGED", {}, 1)

    assert(handled == true, "Handle should claim HOUSE_EDITOR_MODE_CHANGED")
    assert(counter.syncs == 1, "expected one reply-key sync, got " .. counter.syncs)
  end

  -- test_house_editor_mode_change_is_a_lifecycle_event

  do
    local registered = false
    for _, eventName in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
      if eventName == "HOUSE_EDITOR_MODE_CHANGED" then
        registered = true
      end
    end
    assert(registered, "HOUSE_EDITOR_MODE_CHANGED must be registered so the handler ever runs")
  end
end
