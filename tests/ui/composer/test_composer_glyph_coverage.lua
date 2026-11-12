local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Composer = require("WhisperMessenger.UI.Composer")

-- Typing "ő" or "ű" switches the text box to the chat font so the letters
-- show while typing, and back once they are gone.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, Theme.COMPOSER_HEIGHT)
  local composer = Composer.Create(factory, parent, { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }, function() end)
  local input = composer.input

  -- test_typing_double_acute_letters_uses_the_wide_font
  input:SetText("tűzőgép")
  input.scripts.OnTextChanged(input)
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "the box shows ő and ű")

  -- test_typed_text_keeps_its_colour_on_the_wide_font
  local r, g, b = input:GetTextColor()
  local primary = Theme.COLORS.text_primary
  assert(r == primary[1] and g == primary[2] and b == primary[3], "the typed text keeps its colour")

  -- test_plain_text_goes_back_to_the_theme_font
  input:SetText("szia")
  input.scripts.OnTextChanged(input)
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal"), "back to the usual font")
end
