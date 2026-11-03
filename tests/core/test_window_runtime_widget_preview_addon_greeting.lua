local WidgetPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")

-- The toggle-icon popup names CraftScan Craft Alert in a tagged whisper, like
-- its bubble; the stored preview keeps the received text.

return function()
  local text = "Found you via CraftScan: [Item]"
  local conversation = {
    displayName = "Customer",
    channel = "WOW",
    lastIncomingSender = "Customer",
    lastIncomingPreview = text,
    lastIncomingAt = 10,
    messages = { { text = text, direction = "in", kind = "user", addonGreeting = "CraftScan" } },
  }
  local preview = WidgetPreview.Create({
    accountState = { conversations = { ["wow::customer"] = conversation } },
    runtimeStore = { conversations = {} },
  })

  local latest = preview.buildLatestIncomingPreview({ { conversationKey = "wow::customer", displayName = "Customer", channel = "WOW" } })
  assert(latest ~= nil, "a preview is built")
  assert(latest.messageText == "Found you via Craft Alert: [Item]", "tagged preview renamed, got " .. tostring(latest.messageText))
  assert(conversation.lastIncomingPreview == text, "the stored preview stays as received")
end
