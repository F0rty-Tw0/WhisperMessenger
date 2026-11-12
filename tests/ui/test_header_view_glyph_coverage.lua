local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local HeaderView = require("WhisperMessenger.UI.ConversationPane.HeaderView")

-- A chat partner called "Kőszívű" is named at the top in the chat font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(600, 420)

  -- test_header_name_with_double_acute_letters_uses_the_wide_font
  local header = HeaderView.Create(factory, pane, { displayName = "Kőszívű", channel = "WOW", conversationKey = "me::WOW::k" })
  assert(header.headerName:GetFontObject() == rawget(_G, "WM_HighlightLarge_Wide"), "the name needs the chat font")

  -- test_switching_to_a_plain_name_goes_back_to_the_usual_font
  HeaderView.Refresh(header, { displayName = "Jaina", channel = "WOW", conversationKey = "me::WOW::j" }, nil, nil)
  assert(header.headerName:GetFontObject() == rawget(_G, "WM_HighlightLarge"), "a plain name keeps the theme font")

  -- test_refresh_to_a_double_acute_name_uses_the_wide_font
  HeaderView.Refresh(header, { displayName = "Łucja", channel = "WOW", conversationKey = "me::WOW::l" }, nil, nil)
  assert(header.headerName:GetFontObject() == rawget(_G, "WM_HighlightLarge_Wide"), "the refreshed name needs the chat font")
end
