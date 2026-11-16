local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")
local ComposerRows = require("WhisperMessenger.UI.Composer.ComposerRows")

local function stubStringHeight(fontString, getStringHeight)
  fontString.GetStringHeight = getStringHeight
end

return function()
  local factory = FakeUI.NewFactory({ wrap = true })
  Fonts.Initialize("default")
  local pane = factory.CreateFrame("Frame", "pane", nil)
  local rows = ComposerRows.Create(pane, Theme.FONTS.composer_input)

  -- test_bar_height_grows_one_line_per_row
  assert(ComposerRows.BarHeight(1, 12) == 44, "one row keeps the 44 px bar")
  assert(ComposerRows.BarHeight(2, 12) == 56, "two rows add one line")
  assert(ComposerRows.BarHeight(3, 12) == 68, "three rows add two lines")

  -- test_row_cap_follows_the_room_the_window_gives
  assert(ComposerRows.MAX_ROWS == 2, "the box stops at two rows")
  assert(ComposerRows.RowCap(nil, 12) == 2, "no limit allows two rows")
  assert(ComposerRows.RowCap(68, 12) == 2, "room for three rows still stops at two")
  assert(ComposerRows.RowCap(56, 12) == 2, "room for two rows")
  assert(ComposerRows.RowCap(50, 12) == 1, "half a line of spare room is not a row")
  assert(ComposerRows.RowCap(30, 12) == 1, "never below one row")

  -- test_count_is_the_wrapped_line_count
  assert(rows.count("", 70) == 1, "empty text is one row")
  assert(rows.count(("a"):rep(10), 70) == 1, "ten letters fit a 70 px line")
  assert(rows.count(("a"):rep(11), 70) == 2, "eleven letters wrap once")
  assert(rows.count(("a"):rep(25), 70) == 3, "25 letters take three rows")

  -- test_fit_caps_rows_and_reports_the_bar_height
  local count, bar = rows.fit(nil, 70, nil)
  assert(count == 1 and bar == 44, "no text is one row, got " .. tostring(count) .. "/" .. tostring(bar))
  count, bar = rows.fit(("a"):rep(11), 70, nil)
  assert(count == 2 and bar == 56, "two rows, got " .. tostring(count) .. "/" .. tostring(bar))
  count, bar = rows.fit(("a"):rep(25), 70, 50)
  assert(count == 1 and bar == 44, "the window cap holds it to one row, got " .. tostring(count) .. "/" .. tostring(bar))
  count, bar = rows.fit(("a"):rep(100), 70, nil)
  assert(count == 2 and bar == 56, "long text stops at two rows, got " .. tostring(count) .. "/" .. tostring(bar))

  -- test_line_height_follows_the_font_size
  assert(rows.lineHeight() == 12, "default input font is 12 px")
  Fonts.SetFontSize(16)
  assert(rows.lineHeight() == 16, "line height follows the font size")
  Fonts.Initialize("default")

  -- test_line_height_falls_back_before_the_font_exists
  local unbuilt = ComposerRows.Create(pane, "WM_NotYetBuiltFont")
  assert(unbuilt.lineHeight() == 12, "a font not built yet counts as 12 px, got " .. tostring(unbuilt.lineHeight()))

  -- test_line_height_is_the_measured_line_pitch
  -- The measurer reports `perLine` px per line (nil = no answer).
  local perLine
  local measured = ComposerRows.Create(pane, Theme.FONTS.composer_input)
  stubStringHeight(measured.measurer, function(self)
    return perLine and self:GetNumLines() * perLine
  end)
  perLine = 32 / 3
  local pitch = measured.lineHeight()
  assert(math.abs(pitch - 32 / 3) < 1e-9, "line height is the measured pitch, got " .. tostring(pitch))

  -- test_line_height_falls_back_to_the_font_size_when_unmeasured
  perLine = 0
  assert(measured.lineHeight() == 12, "a zero measurement counts the font size, got " .. tostring(measured.lineHeight()))
  perLine = nil
  assert(measured.lineHeight() == 12, "no measurement counts the font size, got " .. tostring(measured.lineHeight()))

  -- test_measurer_follows_the_text_onto_the_chat_font
  local chatRows = ComposerRows.Create(pane, "WM_ChatNormal")
  chatRows.count("tűz", 70)
  assert(chatRows.measurer:GetFont() == "Fonts\\ARIALN.TTF", "ű puts the measurer on the chat font, got " .. tostring(chatRows.measurer:GetFont()))
  chatRows.count("tuz", 70)
  assert(chatRows.measurer:GetFont() == "Fonts\\FRIZQT__.TTF", "plain text puts it back, got " .. tostring(chatRows.measurer:GetFont()))

  -- test_fit_measures_the_pitch_on_the_new_texts_font
  -- The pitch is read after count has put the measurer on the font the text needs.
  local pitchRows = ComposerRows.Create(pane, "WM_ChatNormal")
  local pitchFace
  local realHeight = pitchRows.measurer.GetStringHeight
  pitchRows.measurer.GetStringHeight = function(self)
    if self.text == "X\nX" then
      pitchFace = self:GetFont()
    end

    return realHeight(self)
  end
  pitchRows.fit("tűz", 70, nil)
  assert(pitchFace == "Fonts\\ARIALN.TTF", "the pitch is measured on the chat font, got " .. tostring(pitchFace))

  -- test_measurer_stays_hidden
  assert(rows.measurer:IsShown() == false, "the measurer is never shown")
end
