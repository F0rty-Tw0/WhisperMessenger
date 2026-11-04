local WidgetPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")

return function()
  local accountState = {
    conversations = {
      ["wow::jaina"] = {
        displayName = "Jaina",
        channel = "WOW",
        lastIncomingSender = "Jaina",
        lastIncomingPreview = "Need assistance?",
        lastIncomingAt = 10,
      },
      ["wow::thrall"] = {
        displayName = "Thrall",
        channel = "WOW",
        lastIncomingSender = "Thrall",
        lastIncomingPreview = "Lok'tar.",
        lastIncomingAt = 30,
      },
      ["party::1"] = {
        displayName = "Party Chat",
        channel = "PARTY",
        lastIncomingSender = "Party",
        lastIncomingPreview = "Ignored group preview",
        lastIncomingAt = 40,
      },
    },
  }

  local preview = WidgetPreview.Create({
    accountState = accountState,
    runtimeStore = { conversations = {} },
  })

  local contacts = {
    { conversationKey = "wow::jaina", displayName = "Jaina", channel = "WOW" },
    { conversationKey = "wow::thrall", displayName = "Thrall", channel = "WOW" },
    { conversationKey = "party::1", displayName = "Party Chat", channel = "PARTY" },
  }

  -- test_latest_preview_carries_the_contact_channel
  local found = preview.findLatestIncomingPreview(contacts)
  assert(found.channel == "WOW", "the preview carries its contact's channel, got " .. tostring(found.channel))

  -- test_acknowledge_through_raises_only_forward
  preview.acknowledgeWidgetPreviewThrough(10)
  assert(accountState.widgetPreviewAcknowledgedAt == 10, "first ack sets the mark")
  preview.acknowledgeWidgetPreviewThrough(5)
  assert(accountState.widgetPreviewAcknowledgedAt == 10, "an older stamp never lowers it")

  -- test_newer_message_still_previews_after_acknowledge_through
  local afterAck = preview.buildLatestIncomingPreview(contacts)
  assert(afterAck and afterAck.senderName == "Thrall", "Thrall's newer whisper still shows after acking through Jaina's")

  accountState.widgetPreviewAcknowledgedAt = nil -- the original rows below start unacknowledged

  local latest = preview.buildLatestIncomingPreview(contacts)
  assert(latest ~= nil, "latest preview should exist")
  assert(latest.senderName == "Thrall", "latest whisper preview should win over older whisper and any group chat")
  assert(latest.messageText == "Lok'tar.", "latest preview should surface latest incoming text")

  preview.acknowledgeLatestWidgetPreview(contacts)
  assert(accountState.widgetPreviewAcknowledgedAt == 30, "acknowledge should persist the latest preview timestamp")
  assert(preview.buildLatestIncomingPreview(contacts) == nil, "acknowledged preview should hide until a newer message arrives")

  accountState.conversations["wow::jaina"].lastIncomingAt = 31
  accountState.conversations["wow::jaina"].lastIncomingPreview = "Meet by the bank."
  local newer = preview.buildLatestIncomingPreview(contacts)
  assert(newer ~= nil and newer.senderName == "Jaina", "newer whisper should show after acknowledged preview")

  accountState.settings = { showWidgetMessagePreview = false }
  assert(preview.buildLatestIncomingPreview(contacts) == nil, "setting should suppress widget preview")
end
