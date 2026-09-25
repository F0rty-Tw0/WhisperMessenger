local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

-- Bubble buttons (Send now / Discard / Retry) reach the model through the
-- window callbacks; a send kept in history clears the composer.
local KEY = "me::WOW::thrall"

return function()
  local handled = {}
  local queued = { direction = "out", kind = "user", text = "gg", delivery = "queued" }
  local runtime = { store = { conversations = { [KEY] = { messages = { queued } } } } }
  local callbacks = WindowCallbacks.Create({
    runtime = runtime,
    characterState = {},
    refreshWindow = function() end,
    sendHandler = {
      HandleSend = function(_runtime, payload)
        handled[#handled + 1] = payload
        payload.deliveryRecorded = payload.text == "queued please"
        return false
      end,
    },
  })

  -- test_on_send_reports_accepted_when_the_text_is_kept_in_history
  assert(callbacks.onSend({ conversationKey = KEY, text = "queued please" }) == true, "queued: composer may clear")
  assert(callbacks.onSend({ conversationKey = KEY, text = "unavailable" }) == false, "not kept: composer keeps the text")

  -- test_message_action_discards_through_the_model
  local result = callbacks.onMessageAction({ conversationKey = KEY, channel = "WOW" }, queued, "discard")
  assert(result == true and #runtime.store.conversations[KEY].messages == 0, "discard removes the queued message")
  assert(callbacks.onMessageAction(nil, queued, "discard") == false, "no conversation: ignored")
end
