local WidgetPreview = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")

return function()
  local accountState = {
    conversations = {
      ["bnet::Arthas#1234"] = {
        displayName = "Arthas#1234",
        channel = "BN",
        lastIncomingSender = "Arthas#1234",
        lastIncomingPreview = "hi",
        lastIncomingAt = 10,
      },
    },
  }
  local preview = WidgetPreview.Create({ accountState = accountState, runtimeStore = { conversations = {} } })
  local contacts = { { conversationKey = "bnet::Arthas#1234", displayName = "Arthas#1234", channel = "BN" } }

  -- test_popup_sender_hides_battletag_numbers
  local latest = preview.buildLatestIncomingPreview(contacts)
  assert(latest ~= nil and latest.senderName == "Arthas", "popup hides the BattleTag number, got " .. tostring(latest and latest.senderName))
end
