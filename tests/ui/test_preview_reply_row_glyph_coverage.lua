local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local PreviewReplyRow = require("WhisperMessenger.UI.ToggleIcon.PreviewReplyRow")

-- The popup's quick reply box starts on its base font and stays on it for plain text.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local card = factory.CreateFrame("Frame", nil, nil)
  card:Show()
  local row = PreviewReplyRow.Create(factory, card, {})
  row.setShown(true)
  local input = row.input

  -- test_reply_box_starts_on_the_base_font_before_typing
  local base = rawget(_G, "WM_ChatNormal")
  assert(input.fontObject == base, "the reply box is on the base font before typing")
  assert(input:GetFont() == "Fonts\\FRIZQT__.TTF", "on the base font file, got " .. tostring(input:GetFont()))

  -- test_plain_typing_keeps_the_base_font
  input:SetText("thanks")
  input:GetScript("OnTextChanged")(input)
  assert(input.fontObject == base and input:GetFont() == "Fonts\\FRIZQT__.TTF", "plain text stays on the base font")

  -- test_typing_ő_moves_the_reply_box_to_the_chat_font_and_back
  input:SetText("ő")
  input:GetScript("OnTextChanged")(input)
  assert(input:GetFont() == "Fonts\\ARIALN.TTF", "ő moves the reply box to the chat font, got " .. tostring(input:GetFont()))
  input:SetText("ok")
  input:GetScript("OnTextChanged")(input)
  assert(input:GetFont() == "Fonts\\FRIZQT__.TTF", "plain text moves it back, got " .. tostring(input:GetFont()))
end
