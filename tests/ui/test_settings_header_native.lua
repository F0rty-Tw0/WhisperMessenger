-- Under the Native WoW HUD a settings section title reads like the game's
-- own: left-aligned large game font in the preset's title colour, one
-- divider line under it, then the hint.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Shapes = require("WhisperMessenger.UI.Helpers.Shapes")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")

local TITLE_FONT = "GameFontNormalLarge"

local function colorsMatch(a, b)
  return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function lastPoint(region, anchor)
  local found
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == anchor then
      found = pt
    end
  end
  return found
end

local function build()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  Hud.Configure("classic")
  local header = SettingsControls.CreateHeader(frame, { title = "Apparence", hint = "Hint text" })
  Hud.Configure("off")
  return header, frame
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")
  local padding = Theme.CONTENT_PADDING

  -- test_hud_title_is_left_aligned_large_game_font
  do
    local header, frame = build()
    local tl = lastPoint(header.title, "TOPLEFT")
    assert(tl and tl[2] == frame and tl[4] == padding and tl[5] == -padding, "HUD: title sits at the top-left padding")
    assert(lastPoint(header.title, "TOP") == nil, "HUD: title is not centred")
    assert(header.title.fontObject == (_G[TITLE_FONT] or TITLE_FONT), "HUD: GameFontNormalLarge title")
    assert(colorsMatch(header.title.textColor, Theme.COLORS.text_title), "HUD: preset title colour")
  end

  -- test_hud_one_divider_under_the_title
  do
    local header = build()
    local left, right = header.leftLine, header.rightLine
    assert(lastPoint(left, "TOPLEFT")[2] == header.title, "HUD: divider starts under the title")
    assert(lastPoint(right, "LEFT")[2] == left, "HUD: divider halves meet as one line")
    assert(lastPoint(left, "RIGHT") == nil, "HUD: no line flanking the title")
    assert(left.height == Shapes.hairlineThickness(left, 1), "HUD: divider is a pixel hairline")
    assert(left.width + right.width == Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, "HUD: divider spans the control band")
  end

  -- test_hud_hint_follows_the_divider_in_secondary_colour
  do
    local header = build()
    assert(header.hint.text == "Hint text", "HUD: hint kept")
    assert(lastPoint(header.hint, "TOPLEFT")[2] == header.leftLine, "HUD: hint sits under the divider")
    assert(colorsMatch(header.hint.textColor, Theme.COLORS.text_secondary), "HUD: hint in secondary colour")
  end

  -- test_hud_theme_refresh_recolours_and_stays_native
  do
    local header = build()
    Theme.SetPreset("wow_native")
    header.refreshTheme(Theme)
    assert(colorsMatch(header.title.textColor, Theme.COLORS.text_title), "HUD refresh: new title colour")
    assert(header.title.fontObject == (_G[TITLE_FONT] or TITLE_FONT), "HUD refresh: keeps the game font")
    Theme.SetPreset("wow_default")
  end

  -- test_hud_refresh_layout_resizes_the_divider
  do
    local header = build()
    header.refreshLayout(300)
    assert(header.leftLine.width + header.rightLine.width == 300, "HUD: divider follows the panel width")
  end

  Theme.SetPreset(previousPreset)
end
