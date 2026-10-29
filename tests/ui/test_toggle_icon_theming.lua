local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local IconRing = require("WhisperMessenger.UI.Shared.IconRing")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")

local function colorsMatch(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  local function round(n)
    return math.floor((n or 0) * 1000 + 0.5)
  end
  return round(a[1]) == round(b[1]) and round(a[2]) == round(b[2]) and round(a[3]) == round(b[3]) and round(a[4] or 1) == round(b[4] or 1)
end

return function()
  local previousPreset = Theme.GetPreset()

  -- -----------------------------------------------------------------------
  -- Icon exposes a refreshTheme() function so the preset-switch flow can
  -- repaint the ring and logo without a /reload.
  -- -----------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})
    assert(type(icon.refreshTheme) == "function", "toggle_icon_refresh: should expose a refreshTheme function")
  end

  -- -----------------------------------------------------------------------
  -- Presets paint the icon with their color roles: the ring takes
  -- toggle_icon_ring (fully opaque, the art carries the shading), the logo
  -- toggle_icon_glyph.
  -- -----------------------------------------------------------------------
  Hud.Configure("classic")
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})

    assert(
      icon.border.texturePath == IconRing.RING.classic,
      "modern_icon: ring should use the HUD's ring, got: " .. tostring(icon.border.texturePath)
    )
    assert(colorsMatch(icon.border.vertexColor, IconRing.RingColor(Theme.COLORS)), "modern_icon: ring should be tinted with toggle_icon_ring role")
    assert(colorsMatch(icon.label.vertexColor, Theme.COLORS.toggle_icon_glyph), "modern_icon: glyph should be tinted with toggle_icon_glyph role")
  end

  -- -----------------------------------------------------------------------
  -- Azeroth (wow_native) tints the same ring art gold. Only the color tint
  -- carries the theme.
  -- -----------------------------------------------------------------------
  do
    Theme.SetPreset("wow_native")
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})

    assert(icon.border.texturePath == IconRing.RING.classic, "azeroth_icon: same ring art, got: " .. tostring(icon.border.texturePath))
    assert(
      colorsMatch(icon.border.vertexColor, IconRing.RingColor(Theme.COLORS)),
      "azeroth_icon: ring should be tinted with toggle_icon_ring role (gold)"
    )
  end

  -- -----------------------------------------------------------------------
  -- refreshTheme repaints tints live when the preset changes. The ring
  -- texture stays constant across presets; only the color shifts.
  -- -----------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local icon = ToggleIcon.Create(factory, {})

    local src = icon.border.vertexColor or {}
    local modernRingColor = { src[1], src[2], src[3], src[4] }

    Theme.SetPreset("wow_native")
    icon.refreshTheme()

    assert(icon.border.texturePath == IconRing.RING.classic, "refresh_icon: ring texture stays the same across preset switch")
    assert(
      colorsMatch(icon.border.vertexColor, IconRing.RingColor(Theme.COLORS)),
      "refresh_icon: ring tint should match wow_native toggle_icon_ring after refresh"
    )
    assert(not colorsMatch(icon.border.vertexColor, modernRingColor), "refresh_icon: ring tint should differ between wow_default and wow_native")
  end
  Hud.Configure("off")

  if previousPreset then
    Theme.SetPreset(previousPreset)
  end

  print("  All toggle icon theming tests passed")
end
