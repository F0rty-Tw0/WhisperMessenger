-- The minimap button wears the same face as the widget: the dark circle, the
-- two bubbles, no ring. Only the back bubble grays while idle, hover lifts
-- the circle.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local IconArt = require("WhisperMessenger.UI.ToggleIcon.IconArt")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function createIcon(desaturated, unreadCount)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Minimap", nil)
  parent:SetSize(140, 140)
  return MinimapIcon.Create(factory, {
    parent = parent,
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

  -- test_minimap_draws_the_circle_and_bubbles_without_a_ring
  do
    local icon = createIcon(false)
    assert(icon.border == nil, "no ring")
    assert(sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), "dark circle color")
    assert(icon.background.texturePath == IconArt.CIRCLE_TEX, "circle texture")
    assert(icon.iconTex.texturePath == SquareLook.GLYPH_TEXTURE, "front bubble texture")
    assert(icon.iconTex.width == 30 * IconArt.GLYPH_RATIO, "front bubble at the glyph ratio, got " .. tostring(icon.iconTex.width))
    assert(sameColor(icon.iconTex.vertexColor, Theme.COLORS.toggle_icon_glyph), "front bubble color")
    assert(icon.accentGlyph.shown == true, "back bubble shown")
  end

  -- test_minimap_hover_lifts_the_circle
  do
    local icon = createIcon(true)
    icon.setUnreadCount(0)
    local glyphColor = icon.iconTex.vertexColor

    fire(icon, "OnEnter")
    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "circle lifts on hover")
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "back bubble accent on hover")
    assert(sameColor(icon.iconTex.vertexColor, glyphColor), "front bubble unchanged on hover")
  end

  -- test_minimap_leave_restores_the_circle_and_the_gray_back
  do
    local icon = createIcon(true)
    icon.setUnreadCount(0)
    fire(icon, "OnEnter")

    fire(icon, "OnLeave")
    assert(sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), "circle back on leave")
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "back bubble gray again on leave")
  end

  -- test_minimap_hover_keeps_the_lift_across_unread_changes
  do
    local icon = createIcon(true)
    icon.setUnreadCount(0)
    fire(icon, "OnEnter")

    icon.setUnreadCount(3)
    icon.setUnreadCount(0)
    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "lift kept across unread changes")
    assert(sameColor(icon.accentGlyph.vertexColor, Theme.COLORS.accent), "hovered, so never gray")
  end

  -- test_minimap_theme_change_repaints
  do
    local icon = createIcon(true)
    icon.setUnreadCount(0)
    local current = Theme.COLORS.toggle_icon_bg
    local oldBg = { current[1], current[2], current[3], current[4] }

    Theme.SetPreset("wow_native")
    icon.refreshTheme()
    assert(sameColor(icon.background.vertexColor, Theme.COLORS.toggle_icon_bg), "idle circle takes the new theme")
    assert(not sameColor(icon.background.vertexColor, oldBg), "not the old theme's circle")
    assert(sameColor(icon.iconTex.vertexColor, Theme.COLORS.toggle_icon_glyph), "front bubble takes the new theme")

    fire(icon, "OnEnter")
    Theme.SetPreset("wow_default")
    icon.refreshTheme()
    assert(sameColor(icon.background.vertexColor, IconArt.ResolveHoverBgColor()), "hovered circle takes the new theme's lift")
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
