local WidgetPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")

-- A message request never pops the incoming-message preview while the
-- Requests inbox is on.
return function()
  local accountState = {
    settings = { requestsInbox = true },
    conversations = {
      ["wow::jaina"] = { displayName = "Jaina", channel = "WOW", lastIncomingPreview = "older", lastIncomingAt = 10 },
      ["wow::stranger"] = { displayName = "Stranger", channel = "WOW", lastIncomingPreview = "newer", lastIncomingAt = 30, request = true },
    },
  }
  local preview = WidgetPreview.Create({ accountState = accountState, runtimeStore = { conversations = {} } })
  local contacts = {
    { conversationKey = "wow::jaina", displayName = "Jaina", channel = "WOW" },
    { conversationKey = "wow::stranger", displayName = "Stranger", channel = "WOW" },
  }

  -- test_request_is_skipped_for_the_popup
  local latest = preview.buildLatestIncomingPreview(contacts)
  assert(latest ~= nil and latest.senderName == "Jaina", "the request is skipped, Jaina shows")

  -- test_inbox_off_previews_the_request_again
  accountState.settings.requestsInbox = false
  latest = preview.buildLatestIncomingPreview(contacts)
  assert(latest ~= nil and latest.senderName == "Stranger", "inbox off: flag ignored")
end
