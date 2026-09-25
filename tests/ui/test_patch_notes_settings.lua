-- What's New options page renders the shipped release notes.
local FakeUI = require("tests.helpers.fake_ui")
local PatchNotesSettings = require("WhisperMessenger.UI.MessengerWindow.PatchNotesSettings")
local Theme = require("WhisperMessenger.UI.Theme")
local FindUI = require("tests.helpers.find_ui")
local Shapes = require("WhisperMessenger.UI.Helpers.Shapes")

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

  -- test_missing_version_and_lines_do_not_error

  do
    local view = newView({})
    assert(headerTitle(view).text == "What's New", "expected a bare title when no version shipped")
    assert(#blocks(view) == 0 and #dividers(view) == 0, "expected no notes or dividers when no lines shipped")
    assert(view.frame._wmBottomMarker.point[2] == headerHint(view), "expected the bottom marker under the hint")
  end
end
