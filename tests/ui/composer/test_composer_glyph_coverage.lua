local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Composer = require("WhisperMessenger.UI.Composer")

-- The text box sits on the chat-font twin from the start, so "ő" and "ű"
-- show while typing: a live edit box ignores a font swap made mid-edit.
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, Theme.COMPOSER_HEIGHT)
  local composer = Composer.Create(factory, parent, { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }, function() end)
  local input = composer.input

  -- test_input_starts_on_the_wide_font_before_typing
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "the box is on the wide font before any typing")

  -- test_input_keeps_its_colour_on_the_wide_font
  local r, g, b = input:GetTextColor()
  local primary = Theme.COLORS.text_primary
  assert(r == primary[1] and g == primary[2] and b == primary[3], "the typed text keeps its colour")

  -- test_typing_never_swaps_the_font
  local swaps = 0
  local setFontObject = input.SetFontObject
  ---@diagnostic disable-next-line: duplicate-set-field
  input.SetFontObject = function(self, font)
    swaps = swaps + 1
    setFontObject(self, font)
  end
  input:SetText("tűzőgép")
  input.scripts.OnTextChanged(input)
  input:SetText("szia")
  input.scripts.OnTextChanged(input)
  assert(swaps == 0, "typing leaves the font alone, got " .. swaps .. " swaps")
  assert(input:GetFontObject() == rawget(_G, "WM_ChatNormal_Wide"), "still on the wide font")

  -- test_font_size_change_puts_the_box_back_on_the_wide_font_without_reading_it
  -- In game a live edit box answers nil to GetFontObject.
  input.GetFontObject = function()
    return nil
  end
  local lastFont
  ---@diagnostic disable-next-line: duplicate-set-field
  input.SetFontObject = function(self, font)
    lastFont = font
    setFontObject(self, font)
  end
  Fonts.SetFontSize(16)
  assert(lastFont == rawget(_G, "WM_ChatNormal_Wide"), "the size change re-points the box at the wide font")
  r, g, b = input:GetTextColor()
  assert(r == primary[1] and g == primary[2] and b == primary[3], "the refresh keeps the text colour")
  Fonts.Initialize("default")
end
