local WidgetPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")

-- A muted conversation never pops the incoming-message preview.
return function()
  local accountState = {
    conversations = {
      ["wow::jaina"] = { displayName = "Jaina", channel = "WOW", lastIncomingPreview = "older", lastIncomingAt = 10 },
      ["wow::thrall"] = { displayName = "Thrall", channel = "WOW", lastIncomingPreview = "newer", lastIncomingAt = 30, muted = true },
    },
  }
  local preview = WidgetPreview.Create({ accountState = accountState, runtimeStore = { conversations = {} } })
  local contacts = {
    { conversationKey = "wow::jaina", displayName = "Jaina", channel = "WOW" },
    { conversationKey = "wow::thrall", displayName = "Thrall", channel = "WOW" },
  }

  -- test_muted_conversation_is_skipped_for_the_popup
  local latest = preview.buildLatestIncomingPreview(contacts)
  assert(latest ~= nil and latest.senderName == "Jaina", "muted Thrall is skipped, unmuted Jaina shows")

  -- test_only_muted_conversations_show_no_popup
  accountState.conversations["wow::jaina"].muted = true
  assert(preview.buildLatestIncomingPreview(contacts) == nil, "nothing to preview when every sender is muted")

  -- test_unmuting_does_not_pop_a_message_seen_in_the_window
  preview.acknowledgeLatestWidgetPreview(contacts)
  accountState.conversations["wow::thrall"].muted = nil
  accountState.conversations["wow::jaina"].muted = nil
  assert(preview.buildLatestIncomingPreview(contacts) == nil, "Thrall's muted message was already on screen; unmuting does not pop it")
end
