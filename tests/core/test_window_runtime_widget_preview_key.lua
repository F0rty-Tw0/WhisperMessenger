local WidgetPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")

-- The preview names the conversation it came from, so a click can open it.
return function()
  local accountState = {
    conversations = {
      ["wow::jaina"] = { displayName = "Jaina", channel = "WOW", lastIncomingPreview = "older", lastIncomingAt = 10 },
      ["wow::thrall"] = { displayName = "Thrall", channel = "WOW", lastIncomingPreview = "newer", lastIncomingAt = 30 },
    },
  }
  local preview = WidgetPreview.Create({ accountState = accountState, runtimeStore = { conversations = {} } })
  local contacts = {
    { conversationKey = "wow::jaina", displayName = "Jaina", channel = "WOW" },
    { conversationKey = "wow::thrall", displayName = "Thrall", channel = "WOW" },
  }

  -- test_preview_carries_the_latest_conversation_key
  local latest = preview.buildLatestIncomingPreview(contacts)
  assert(latest ~= nil and latest.conversationKey == "wow::thrall", "the newest whisper's key rides on the preview")
end
