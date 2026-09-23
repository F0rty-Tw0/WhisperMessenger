-- What's New options page renders the shipped release notes.
local FakeUI = require("tests.helpers.fake_ui")
local PatchNotesSettings = require("WhisperMessenger.UI.MessengerWindow.PatchNotesSettings")
local Theme = require("WhisperMessenger.UI.Theme")
local FindUI = require("tests.helpers.find_ui")

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

-- The body is the page's last FontString, after the header title and hint.
local function bodyText(view)
  local fontStrings = FindUI.ofType(view.frame, "FontString")
  return fontStrings[#fontStrings]
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

  -- test_body_uses_message_text_font_and_lists_every_line

  do
    local view = newView(NOTES)
    local body = bodyText(view)
    assert(body ~= nil and body ~= headerHint(view), "expected the page to render a body text below the header")
    assert(bodyText(view).template == Theme.FONTS.message_text, "expected the body to follow the Options chat font size")
    assert(bodyText(view).justifyH == "LEFT", "expected the body to be left aligned")
    for _, line in ipairs(NOTES.lines) do
      assert(string.find(bodyText(view).text, line, 1, true), "expected the body to list: " .. line)
    end
    assert(string.find(bodyText(view).text, "• ", 1, true), "expected the body to bullet each line")
  end

  -- test_bottom_marker_tracks_the_body

  do
    local view = newView(NOTES)
    local marker = view.frame._wmBottomMarker
    assert(marker ~= nil, "expected a bottom marker so the options scrollview can measure the page")
    assert(marker.point ~= nil and marker.point[2] == bodyText(view), "expected the bottom marker to anchor under the body text")
  end

  -- test_refresh_layout_sizes_the_body_and_clamps_to_a_readable_minimum

  do
    local view = newView(NOTES)
    view.refreshLayout(400)
    assert(bodyText(view).width == 400, "expected the body to use the full pane width, got " .. tostring(bodyText(view).width))
    view.refreshLayout(10)
    assert(bodyText(view).width == 160, "expected a 160px minimum body width, got " .. tostring(bodyText(view).width))
    view.refreshLayout(nil)
    assert(bodyText(view).width == 160, "expected a nil width to be ignored")
  end

  -- test_refresh_theme_and_set_language_are_safe

  do
    local view = newView(NOTES)
    view.refreshTheme(Theme)
    assert(bodyText(view).textColor ~= nil, "expected refreshTheme to paint the body text")
    view.setLanguage()
    assert(string.find(headerTitle(view).text, NOTES.version, 1, true), "expected setLanguage to keep the version in the title")
  end

  -- test_missing_version_and_lines_do_not_error

  do
    local view = newView({})
    assert(headerTitle(view).text == "What's New", "expected a bare title when no version shipped")
    assert(bodyText(view).text == "", "expected an empty body when no lines shipped")
  end
end
