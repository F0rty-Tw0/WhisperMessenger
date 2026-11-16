local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local Composer = require("WhisperMessenger.UI.Composer")

local FRIZ_FONT = "Fonts\\FRIZQT__.TTF"
local CHAT_FONT = "Fonts\\ARIALN.TTF"

-- The text box keeps its base font object and shows the base font file; the
-- chat font file is swapped in with SetFont only while its text needs "ő" or
-- "ű" (UpdateInput, wired to the box's OnTextChanged).
return function()
  local factory = FakeUI.NewFactory({ fontColors = true })
  Fonts.Initialize("default")
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, Theme.COMPOSER_HEIGHT)
  local composer = Composer.Create(factory, parent, { conversationKey = "me::WOW::a", displayName = "A", channel = "WOW" }, function() end)
  local input = composer.input
  local base = rawget(_G, "WM_ChatNormal")

  -- test_input_starts_on_the_base_font_before_typing
  assert(input:GetFontObject() == base, "the box is on the base font object before any typing")
  assert(input:GetFont() == FRIZ_FONT, "and on the base font file, got " .. tostring(input:GetFont()))

  -- test_input_keeps_its_colour_on_the_base_font
  local r, g, b = input:GetTextColor()
  local primary = Theme.COLORS.text_primary
  assert(r == primary[1] and g == primary[2] and b == primary[3], "the typed text keeps its colour")

  -- test_typing_ő_swaps_to_the_chat_font_and_back_without_font_objects
  local objectCalls = 0
  local realSetFontObject = input.SetFontObject
  ---@diagnostic disable-next-line: duplicate-set-field
  input.SetFontObject = function(self, font)
    objectCalls = objectCalls + 1
    realSetFontObject(self, font)
  end
  local onChanged = input:GetScript("OnTextChanged")
  input:SetText("tűzőgép")
  onChanged(input, true)
  assert(input:GetFont() == CHAT_FONT, "ő and ű move the box to the chat font, got " .. tostring(input:GetFont()))
  input:SetText("szia")
  onChanged(input, true)
  assert(input:GetFont() == FRIZ_FONT, "plain text moves it back, got " .. tostring(input:GetFont()))
  assert(objectCalls == 0, "typing never calls SetFontObject, got " .. objectCalls)
  input.SetFontObject = realSetFontObject
  input:SetText("")

  -- test_font_size_change_keeps_the_box_on_the_base_font_without_reading_it
  -- In game a live edit box answers nil to GetFontObject.
  input.GetFontObject = function()
    return nil
  end
  local lastFont
  local setFontObject = input.SetFontObject
  ---@diagnostic disable-next-line: duplicate-set-field
  input.SetFontObject = function(self, font)
    lastFont = font
    setFontObject(self, font)
  end
  Fonts.SetFontSize(16)
  assert(lastFont == base, "the size change re-points the box at the base font")
  local path, size = input:GetFont()
  assert(path == FRIZ_FONT and size == 16, "the base face follows the size change, got " .. tostring(size))
  r, g, b = input:GetTextColor()
  assert(r == primary[1] and g == primary[2] and b == primary[3], "the refresh keeps the text colour")
  Fonts.Initialize("default")
end
