-- What's New options page renders the shipped release notes.
local FakeUI = require("tests.helpers.fake_ui")
local PatchNotesSettings = require("WhisperMessenger.UI.MessengerWindow.PatchNotesSettings")
local Theme = require("WhisperMessenger.UI.Theme")
local FindUI = require("tests.helpers.find_ui")
local Shapes = require("WhisperMessenger.UI.Helpers.Shapes")
local Hud = require("WhisperMessenger.UI.Theme.Hud")

local NOTES = {
  version = "v9.9.9",
  date = "2026-01-02",
  lines = {
    "First shiny thing landed.",
    "Second shiny thing landed.",
  },
}

local function newView(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(400, 500)
  return PatchNotesSettings.Create(factory, parent, config, {})
end

-- Header title and hint are the page's first two FontStrings.
local function headerTitle(view)
  return FindUI.ofType(view.frame, "FontString")[1]
end

local function headerHint(view)
  return FindUI.ofType(view.frame, "FontString")[2]
end

-- Each note is its own FontString after the header title and hint.
local function blocks(view)
  local fontStrings = FindUI.ofType(view.frame, "FontString")
  local out = {}
  for index = 3, #fontStrings do
    out[#out + 1] = fontStrings[index]
  end
  return out
end

-- Dividers are the left halves hanging under a note (the header draws its own lines).
local function dividers(view)
  local isNote = {}
  for _, note in ipairs(blocks(view)) do
    isNote[note] = true
  end
  local out = {}
  for _, texture in ipairs(FindUI.ofType(view.frame, "Texture")) do
    if texture.point and isNote[texture.point[2]] then
      out[#out + 1] = texture
    end
  end
  return out
end

-- The right half starts where a divider's left half ends.
local function rightHalf(view, left)
  for _, texture in ipairs(FindUI.ofType(view.frame, "Texture")) do
    if texture.point and texture.point[2] == left then
      return texture
    end
  end
  return nil
end

local function sameRgb(a, b)
  return a ~= nil and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- The plain look's side hairlines hang off the title's edges.
local function headerLines(view)
  local title = headerTitle(view)
  local out = {}
  for _, texture in ipairs(FindUI.ofType(view.frame, "Texture")) do
    if texture.point and texture.point[2] == title then
      out[#out + 1] = texture
    end
  end
  return out
end

-- As in WoW: a FontString given a width reports at most that width.
local function clampToBound(fontString)
  fontString.GetStringWidth = function(self)
    local width = self:GetUnboundedStringWidth()
    if type(self.width) == "number" and self.width > 0 then
      return math.min(width, self.width)
    end
    return width
  end
end

-- Stands in for a bigger font: every byte measures `px` wide.
local function setGlyphWidth(fontString, px)
  fontString.GetUnboundedStringWidth = function(self)
    return #tostring(self.text or "") * px
  end
end

local LONG_VERSION = { version = "v9.9.9-nightly-build-42", date = "2026-01-02", lines = {} }

return function()
  -- test_header_shows_version_and_date

  do
    local view = newView(NOTES)
    assert(view.frame ~= nil, "expected the view to expose its frame")
    local title = headerTitle(view).text
    assert(string.find(title, "What's New", 1, true), "expected the header to say What's New, got " .. tostring(title))
    assert(string.find(title, NOTES.version, 1, true), "expected the header to carry the version, got " .. tostring(title))
    assert(string.find(title, NOTES.date, 1, true), "expected the header to carry the date, got " .. tostring(title))
    assert(
      headerHint(view).text == "See what changed in the latest update. (English only)",
      "expected the hint with the English-only disclaimer, got " .. tostring(headerHint(view).text)
    )
  end

  -- test_each_note_is_its_own_bulleted_block

  do
    local view = newView(NOTES)
    local noteBlocks = blocks(view)
    assert(#noteBlocks == #NOTES.lines, "expected one block per note, got " .. #noteBlocks)
    for index, line in ipairs(NOTES.lines) do
      local block = noteBlocks[index]
      assert(block.text == "• " .. line, "expected a bulleted block for: " .. line .. ", got " .. tostring(block.text))
      assert(block.template == Theme.FONTS.message_text, "expected notes to follow the Options chat font size")
      assert(block.justifyH == "LEFT", "expected notes to be left aligned")
    end
  end

  -- test_section_header_dividers_separate_the_blocks

  do
    local view = newView(NOTES)
    local noteBlocks = blocks(view)
    local lefts = dividers(view)
    assert(#lefts == #NOTES.lines - 1, "expected a divider between each pair of notes, got " .. #lefts)
    local left = lefts[1]
    local right = rightHalf(view, left)
    assert(right ~= nil, "expected the divider's right half next to its left half")
    local headerColor = Theme.COLORS.contacts_border_right or Theme.COLORS.divider
    for _, line in ipairs({ left, right }) do
      assert(line.height == Shapes.hairlineThickness(line, 1), "expected a pixel hairline like the section headers")
      assert(line.snapToPixelGrid == true, "expected the hairline to snap to the pixel grid")
      assert(sameRgb(line.color, headerColor), "expected the section-header line colour")
    end
    assert(left.point[2] == noteBlocks[1], "expected the divider under the first note")
    assert(noteBlocks[2].point[2] == left, "expected the second note under the divider")
  end

  -- test_bottom_marker_tracks_the_last_note

  do
    local view = newView(NOTES)
    local marker = view.frame._wmBottomMarker
    local noteBlocks = blocks(view)
    assert(marker ~= nil, "expected a bottom marker so the options scrollview can measure the page")
    assert(marker.point ~= nil and marker.point[2] == noteBlocks[#noteBlocks], "expected the bottom marker under the last note")
  end

  -- test_refresh_layout_sizes_notes_and_dividers_and_clamps_to_a_readable_minimum

  do
    local view = newView(NOTES)
    view.refreshLayout(400)
    for _, region in ipairs(blocks(view)) do
      assert(region.width == 400, "expected notes to use the full pane width, got " .. tostring(region.width))
    end
    local left = dividers(view)[1]
    assert(left.width + rightHalf(view, left).width == 400, "expected dividers to span the pane width")
    view.refreshLayout(10)
    assert(blocks(view)[1].width == 160, "expected a 160px minimum width, got " .. tostring(blocks(view)[1].width))
    view.refreshLayout(nil)
    assert(blocks(view)[1].width == 160, "expected a nil width to be ignored")
  end

  -- test_refresh_theme_and_set_language_are_safe

  do
    local view = newView(NOTES)
    local left = dividers(view)[1]
    left.color = nil
    view.refreshTheme(Theme)
    assert(blocks(view)[1].textColor ~= nil, "expected refreshTheme to paint the notes")
    assert(left.color ~= nil, "expected refreshTheme to repaint the dividers")
    view.setLanguage()
    assert(string.find(headerTitle(view).text, NOTES.version, 1, true), "expected setLanguage to keep the version in the title")
  end

  -- test_narrow_layout_drops_the_date_from_the_title
  -- Fake FontStrings measure 7 px per byte: the full title is 217 px, the
  -- title without the date 119 px.

  do
    local view = newView(NOTES)
    view.refreshLayout(400)
    assert(headerTitle(view).text == "What's New v9.9.9 · 2026-01-02", "expected the full title when it fits")
    view.refreshLayout(200)
    assert(
      headerTitle(view).text == "What's New v9.9.9",
      "expected the date dropped when the title is too wide, got " .. tostring(headerTitle(view).text)
    )
    view.setLanguage()
    assert(headerTitle(view).text == "What's New v9.9.9", "expected setLanguage to keep the narrow title")
    view.refreshLayout(400)
    assert(headerTitle(view).text == "What's New v9.9.9 · 2026-01-02", "expected the date back once the page widens")
  end

  -- test_title_is_bounded_only_when_the_short_title_still_overflows
  -- "What's New v9.9.9-nightly-build-42" is 238 px, 329 px with the date.

  do
    local view = newView(LONG_VERSION)
    local title = headerTitle(view)
    clampToBound(title)
    view.refreshLayout(200)
    assert(title.text == "What's New v9.9.9-nightly-build-42", "expected the date dropped, got " .. tostring(title.text))
    assert(title.width == 200, "expected the overflowing title bounded to the page width, got " .. tostring(title.width))
    assert(title.wordWrap == false, "expected a single-line title that truncates instead of wrapping")
    view.refreshLayout(400)
    assert(title.text == "What's New v9.9.9-nightly-build-42 · 2026-01-02", "expected the full title once it fits")
    assert((title.width or 0) == 0, "expected the bound lifted once the title fits, got " .. tostring(title.width))
  end

  -- test_plain_title_stays_unbounded_when_it_fits
  -- A title bounded to the band would push the side hairlines off the page.

  do
    local view = newView(NOTES)
    local title = headerTitle(view)
    view.refreshLayout(400)
    assert((title.width or 0) == 0, "expected the fitting title left at auto width, got " .. tostring(title.width))
    view.refreshLayout(200)
    assert(title.text == "What's New v9.9.9", "expected the date dropped, got " .. tostring(title.text))
    assert((title.width or 0) == 0, "expected the shorter title left at auto width, got " .. tostring(title.width))
  end

  -- test_refresh_theme_refits_the_title_for_the_new_font

  do
    local view = newView(NOTES)
    local title = headerTitle(view)
    view.refreshLayout(400)
    setGlyphWidth(title, 14)
    view.refreshTheme(Theme)
    assert(title.text == "What's New v9.9.9", "expected a bigger font to drop the date, got " .. tostring(title.text))
  end

  -- test_set_language_resizes_the_header_lines_around_the_refit_title
  -- At 14 px per byte the short title is 238 px: lines are (400 - 238) / 2 - 8.

  do
    local view = newView(NOTES)
    local title = headerTitle(view)
    view.refreshLayout(400)
    clampToBound(title)
    setGlyphWidth(title, 14)
    view.setLanguage()
    local lines = headerLines(view)
    assert(#lines == 2, "expected the plain look's two header lines, got " .. #lines)
    for _, line in ipairs(lines) do
      assert(line.width == 73, "expected the header lines resized around the refit title, got " .. tostring(line.width))
    end
  end

  -- test_native_look_title_also_drops_the_date

  do
    Hud.Configure("classic")
    local view = newView(NOTES)
    Hud.Configure("off")
    view.refreshLayout(200)
    local title = headerTitle(view)
    assert(title.text == "What's New v9.9.9", "expected the Native look title to drop the date, got " .. tostring(title.text))
    assert(title.wordWrap == false, "expected the Native look title kept to one line")
  end

  -- test_missing_version_and_lines_do_not_error

  do
    local view = newView({})
    assert(headerTitle(view).text == "What's New", "expected a bare title when no version shipped")
    assert(#blocks(view) == 0 and #dividers(view) == 0, "expected no notes or dividers when no lines shipped")
    assert(view.frame._wmBottomMarker.point[2] == headerHint(view), "expected the bottom marker under the hint")
  end
end
