-- The widget's states on a circle preset: the dark circle and the front bubble
-- keep their colors, only the back bubble grays while idle, hover lifts the
-- circle.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local IconArt = require("WhisperMessenger.UI.ToggleIcon.IconArt")
local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function createIcon(desaturated, unreadCount)
  return ToggleIcon.Create(FakeUI.NewFactory(), {
    unreadCount = unreadCount,
    getIconDesaturated = function()
      return desaturated
    end,
  })
end

local function fire(icon, script)
  icon.frame:GetScript(script)(icon.frame)
end

return function()
  Theme.SetPreset("wow_default")

  -- test_idle_desaturate_grays_only_the_back_bubble
  do
    local icon = createIcon(true)
    icon.setUnreadCount(0)
    assert(sameColor(Desaturation.DESAT_BACK, { 0.55, 0.55, 0.55, 1 }), "idle gray is opaque 0.55")
    assert(icon.accentGlyph.shown == true, "back bubble shown on the circle")
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "back bubble gray while idle")
    assert(icon.label.desaturated ~= true, "front bubble not desaturated")
    assert(icon.background.desaturated ~= true, "circle not desaturated")
    assert(sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), "circle keeps its color while idle")
    assert(sameColor(icon.label.vertexColor, Theme.COLORS.toggle_icon_glyph), "front bubble keeps its color while idle")
  end

  -- test_unread_returns_the_back_bubble_to_accent
  do
    local icon = createIcon(true)
    icon.setUnreadCount(2)
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "accent with unread whispers")
    icon.setUnreadCount(0)
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "gray again once read")
  end

  -- test_desaturate_off_keeps_the_back_bubble_accent
  do
    local icon = createIcon(false)
    icon.setUnreadCount(0)
    assert(icon.accentGlyph.shown == true, "back bubble shown")
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "accent with the setting off")
  end

  -- test_hover_lifts_the_circle_and_returns_the_back_to_accent
  do
    local icon = createIcon(true)
    icon.setUnreadCount(0)
    local glyphColor = icon.label.vertexColor

    fire(icon, "OnEnter")
    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "circle lifts on hover")
    assert(not sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), "the lift differs from the idle circle")
    assert(sameColor(icon.label.vertexColor, glyphColor), "front bubble unchanged on hover")
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "back bubble accent on hover")

    fire(icon, "OnMouseDown")
    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "press leaves the circle alone")
    fire(icon, "OnMouseUp")
    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "release leaves the circle alone")

    fire(icon, "OnLeave")
    assert(sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), "circle back on leave")
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "back bubble gray again on leave")
  end

  -- test_theme_change_while_hovered_repaints_the_lift
  do
    Theme.SetPreset("wow_default")
    local icon = createIcon(true)
    icon.setUnreadCount(0)
    fire(icon, "OnEnter")
    local defaultLift = IconArt.ResolveHoverBgColor()

    Theme.SetPreset("wow_native")
    icon.refreshTheme()

    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "new theme's lift")
    assert(not sameColor(icon.background.vertexColor, defaultLift), "not the old theme's lift")
    assert(sameColor(icon.label.vertexColor, Theme.COLORS.toggle_icon_glyph), "front bubble takes the new theme")
    Theme.SetPreset("wow_default")
  end

  -- test_unread_change_while_hovered_keeps_the_lift
  do
    local icon = createIcon(true)
    icon.setUnreadCount(0)
    fire(icon, "OnEnter")

    icon.setUnreadCount(3)
    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "lift kept when unread arrives")
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "accent with unread while hovered")

    icon.setUnreadCount(0)
    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "lift kept when unread clears")
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "hovered, so never gray")
  end

  -- test_paint_face_paints_the_circle_and_the_glyph
  do
    local frame = FakeUI.NewFactory().CreateFrame("Button", nil, nil)
    local art = IconArt.Create(frame, 40)

    IconArt.PaintFace(art, true)
    assert(sameColor(art.background.vertexColor, IconArt.ResolveHoverBgColor()), "hovered: the lift")
    assert(sameColor(art.chatIcon.vertexColor, Theme.COLORS.toggle_icon_glyph), "hovered: glyph color")

    IconArt.PaintFace(art, false)
    assert(sameColor(art.background.vertexColor, Theme.COLORS.toggle_icon_bg), "idle: the plain circle")
    assert(sameColor(art.chatIcon.vertexColor, Theme.COLORS.toggle_icon_glyph), "idle: glyph color")
  end

  -- test_desaturation_without_textures_only_tracks_the_state
  do
    local enabled = true
    local desaturation = Desaturation.Create({
      getIconDesaturated = function()
        return enabled
      end,
    })
    desaturation.refresh()
    assert(desaturation.isActive() == true, "idle with the setting on")
    desaturation.update(2)
    assert(desaturation.isActive() == false, "not idle with unread")
    desaturation.refresh()
    assert(desaturation.isActive() == false, "refresh keeps the unread count")
    desaturation.update(0)
    enabled = false
    assert(not desaturation.isActive(), "setting off")
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
