local FakeUI = require("tests.helpers.fake_ui")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")

return function()
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)

  -- test_channel_header_shows_the_channels_own_icon
  local contact = { conversationKey = "channel::me-realm::trade", displayName = "Trade", channel = "CHANNEL" }
  local view = HeaderView.Create(factory, pane, contact)
  HeaderView.Refresh(view, contact, nil, nil)
  local expected = "Interface\\ICONS\\INV_Misc_Coin_01"
  assert(view.headerClassIcon.texturePath == expected, "header shows the Trade icon, got " .. tostring(view.headerClassIcon.texturePath))
end
