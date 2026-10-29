-- The widget and the minimap button share one look, chosen by the Native
-- WoW HUD style: Off shows the full logo alone; Classic and Modern put the
-- rimless logo inside a hi-res copy of that HUD's minimap button ring,
-- tinted with the theme's ring color. The old low-res disc and hoop are gone.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local IconRing = require("WhisperMessenger.UI.Shared.IconRing")

local function near(a, b)
  return type(a) == "number" and math.abs(a - b) < 1e-6
end

-- Sizes are whole pixels.
local function px(a, b)
  return near(a, math.floor(b))
end

local function sameRgb(a, b)
  return type(a) == "table" and type(b) == "table" and near(a[1], b[1]) and near(a[2], b[2]) and near(a[3], b[3])
end

local function centred(region, frame)
  local p = region.point or {}
  return p[1] == "CENTER" and p[2] == frame and p[3] == "CENTER" and (p[4] or 0) == 0 and (p[5] or 0) == 0
end

local function hidden(region)
  return region.shown ~= true
end

local function widget(size)
  return ToggleIcon.Create(FakeUI.NewFactory(), { iconSize = size or 40 })
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  -- test_kind_follows_the_hud
  assert(IconRing.Kind("off") == nil, "off: no ring")
  assert(IconRing.Kind("classic") == "classic", "classic HUD: classic ring")
  assert(IconRing.Kind("retail") == "modern", "modern (retail) HUD: modern ring")

  -- test_hud_off_widget_is_the_logo_alone
  Hud.Configure("off")
  do
    local icon = widget(40)
    assert(icon.label.texturePath == IconRing.LOGO, "full logo")
    assert(centred(icon.label, icon.frame) and px(icon.label.width, 36), "logo centred at its usual 90%")
    assert(hidden(icon.border), "no ring")
    assert(hidden(icon.background), "no low-res disc behind it")
  end

  -- test_modern_hud_widget_has_the_modern_ring
  Hud.Configure("retail")
  if Hud.Style() == "retail" then
    local icon = widget(40)
    assert(icon.border.texturePath == IconRing.RING.modern and icon.border.shown == true, "modern ring")
    assert(centred(icon.border, icon.frame) and px(icon.border.width, 40 * IconRing.RING_SCALE), "ring centred, scaled")
    assert(icon.label.texturePath == IconRing.RIMLESS_LOGO, "rimless logo inside")
    assert(centred(icon.label, icon.frame) and px(icon.label.width, 40 * IconRing.LOGO_SCALE), "logo centred under the ring")
    assert(hidden(icon.background), "nothing behind the logo")
  end

  -- test_classic_hud_widget_has_the_classic_ring_tinted_by_the_theme
  Hud.Configure("classic")
  do
    local icon = widget(40)
    assert(icon.border.texturePath == IconRing.RING.classic, "classic ring")
    assert(sameRgb(icon.border.vertexColor, Theme.COLORS.toggle_icon_ring), "tinted with the theme's ring color")
    assert(near(icon.border.vertexColor[4], 1), "fully opaque ring")
    Theme.SetPreset("wow_native")
    icon.refreshTheme()
    assert(sameRgb(icon.border.vertexColor, Theme.COLORS.toggle_icon_ring), "follows a preset switch")
    Theme.SetPreset("wow_default")
  end

  -- test_resize_keeps_ring_and_logo_in_proportion
  do
    local icon = widget(40)
    icon.applyIconSize(64)
    assert(px(icon.border.width, 64 * IconRing.RING_SCALE) and px(icon.label.width, 64 * IconRing.LOGO_SCALE), "both rescaled")
    assert(centred(icon.border, icon.frame) and centred(icon.label, icon.frame), "both still centred")
  end

  -- test_idle_gray_includes_the_ring
  do
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {
      getIconDesaturated = function()
        return true
      end,
    })
    icon.setUnreadCount(0)
    assert(not sameRgb(icon.border.vertexColor, Theme.COLORS.toggle_icon_ring), "ring gray when idle")
    icon.setUnreadCount(1)
    assert(sameRgb(icon.border.vertexColor, Theme.COLORS.toggle_icon_ring), "ring tinted with unread")
  end

  -- test_minimap_matches_the_widget
  do
    local minimap = MinimapIcon.Create(FakeUI.NewFactory(), {})
    local frame = minimap.frame
    assert(minimap.border.texturePath == IconRing.RING.classic and centred(minimap.border, frame), "same ring, centred")
    assert(sameRgb(minimap.border.vertexColor, Theme.COLORS.toggle_icon_ring), "same tint")
    assert(minimap.iconTex.texturePath == IconRing.RIMLESS_LOGO and centred(minimap.iconTex, frame), "same logo, centred")
    assert(px(minimap.iconTex.width, frame.width * IconRing.LOGO_SCALE), "same proportions")
    assert(hidden(minimap.background), "no disc behind it")
  end
  Hud.Configure("off")
  do
    local minimap = MinimapIcon.Create(FakeUI.NewFactory(), {})
    assert(minimap.iconTex.texturePath == IconRing.LOGO and hidden(minimap.border), "HUD off: the logo alone")
  end

  Hud.Configure("off")
  if previousPreset then
    Theme.SetPreset(previousPreset)
  end
end
