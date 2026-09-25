local AlertPolicy = require("WhisperMessenger.Model.AlertPolicy")

return function()
  -- test_regular_conversation_alerts
  assert(AlertPolicy.ShouldAlert({ channel = "WOW" }) == true, "an unmuted whisper alerts")

  -- test_unknown_conversation_alerts
  assert(AlertPolicy.ShouldAlert(nil) == true, "a message with no record yet still alerts")

  -- test_muted_conversation_is_silent
  assert(AlertPolicy.ShouldAlert({ channel = "BN", muted = true }) == false, "a muted conversation never alerts")

  -- test_message_request_is_silent_only_while_inbox_is_on
  local request = { channel = "WOW", request = true }
  assert(AlertPolicy.ShouldAlert(request, { requestsInbox = true }) == false, "a message request never alerts")
  assert(AlertPolicy.ShouldAlert(request, { requestsInbox = false }) == true, "inbox off: the flag is ignored")
  assert(AlertPolicy.ShouldAlert(request) == true, "no settings: the flag is ignored")
end
