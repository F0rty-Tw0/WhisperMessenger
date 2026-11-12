local FakeUI = require("tests.helpers.fake_ui")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local PreviewReplyRow = require("WhisperMessenger.UI.ToggleIcon.PreviewReplyRow")

-- Typing "ő" or "ű" in the popup's quick reply box shows them in the chat font.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local card = factory.CreateFrame("Frame", nil, nil)
  card:Show()
  local row = PreviewReplyRow.Create(factory, card, {})
  row.setShown(true)
  local input = row.input

  local function typeText(text)
    input:SetText(text)
    input:GetScript("OnTextChanged")(input)
  end

  -- test_typing_double_acute_letters_uses_the_wide_font
  typeText("köszönöm, főnök")
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "the reply box shows ő")

  -- test_plain_text_goes_back_to_the_usual_font
  typeText("thanks")
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal"), "back to the usual font")
end
