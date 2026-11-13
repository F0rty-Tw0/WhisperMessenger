local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local PreviewReplyRow = require("WhisperMessenger.UI.ToggleIcon.PreviewReplyRow")

-- The popup's quick reply box sits on the chat-font twin from the start, so
-- "ő" and "ű" show while typing.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local card = factory.CreateFrame("Frame", nil, nil)
  card:Show()
  local row = PreviewReplyRow.Create(factory, card, {})
  row.setShown(true)
  local input = row.input

  -- test_reply_box_starts_on_the_wide_font_before_typing
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "the reply box is on the wide font before typing")

  -- test_typing_keeps_the_wide_font
  input:SetText("thanks")
  input:GetScript("OnTextChanged")(input)
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "plain text stays on the wide font")
end
