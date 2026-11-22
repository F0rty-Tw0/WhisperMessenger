-- The edge glow's colour: the active theme's accent by default, a chosen
-- preset's accent, or a custom colour (settings.edgeGlowColor / edgeGlowCustom).
local AnimatedFactory = require("tests.helpers.animated_factory")
local ScreenEdgeSurface = require("WhisperMessenger.UI.ToggleIcon.ScreenEdgeSurface")
local Theme = require("WhisperMessenger.UI.Theme")
local Presets = require("WhisperMessenger.UI.Theme.Presets")

local function build(settings)
  local factory = AnimatedFactory.newAnimatedFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(1920, 1080)
  settings = settings or {}
  local surface = ScreenEdgeSurface.Create(factory, parent, {
    theme = Theme,
    settings = settings,
    getSide = function()
      return "left"
    end,
    isWindowShown = function()
      return false
    end,
  })
  return surface, settings
end

local function rgbOf(surface)
  local vc = surface.glow.pulse.glowTexture.vertexColor
  return vc[1], vc[2], vc[3]
end

local function assertRgb(surface, want, context)
  local r, g, b = rgbOf(surface)
  assert(r == want[1] and g == want[2] and b == want[3], context .. ": got " .. tostring(r) .. "," .. tostring(g) .. "," .. tostring(b))
end

return function()
  -- test_default_follows_the_active_theme_accent
  do
    local surface = build()
    assertRgb(surface, Theme.COLORS.accent, "nothing saved")
  end

  -- test_each_preset_choice_paints_that_presets_accent
  for _, key in ipairs(Theme.ListPresets()) do
    local surface, settings = build()
    settings.edgeGlowColor = key
    surface.refresh()
    assertRgb(surface, Presets.Get(key).accent, key)
  end

  -- test_custom_paints_the_stored_rgb
  do
    local surface = build({ edgeGlowColor = "custom", edgeGlowCustom = { 0.25, 0.5, 0.75 } })
    assertRgb(surface, { 0.25, 0.5, 0.75 }, "custom")
  end

  -- test_custom_without_a_colour_or_an_unknown_key_falls_back_to_the_theme
  do
    assertRgb(build({ edgeGlowColor = "custom" }), Theme.COLORS.accent, "custom, nothing stored")
    assertRgb(build({ edgeGlowColor = "gone_preset" }), Theme.COLORS.accent, "unknown preset")
  end

  -- test_a_saved_custom_colour_is_validated_and_clamped
  do
    assertRgb(build({ edgeGlowColor = "custom", edgeGlowCustom = { 2, -1, 0.5 } }), { 1, 0, 0.5 }, "clamped to 0-1")
    assertRgb(build({ edgeGlowColor = "custom", edgeGlowCustom = { "x", 1, 1 } }), Theme.COLORS.accent, "non-number entry")
    assertRgb(build({ edgeGlowColor = "custom", edgeGlowCustom = { 1, 1 } }), Theme.COLORS.accent, "missing blue")
    assertRgb(build({ edgeGlowColor = "custom", edgeGlowCustom = "red" }), Theme.COLORS.accent, "not a table")
  end

  -- test_a_theme_change_recolours_an_unset_glow_but_not_a_chosen_one
  do
    local other = { COLORS = { accent = { 0.1, 0.2, 0.3, 1 } } }
    local surface = build()
    surface.refreshTheme(other)
    assertRgb(surface, other.COLORS.accent, "unset follows the theme")
    local chosen, settings = build({ edgeGlowColor = "custom", edgeGlowCustom = { 1, 0, 0 } })
    chosen.refreshTheme(other)
    assertRgb(chosen, { 1, 0, 0 }, "custom stays")
    settings.edgeGlowColor = nil
    chosen.refresh()
    assertRgb(chosen, other.COLORS.accent, "cleared: back to the theme last painted")
  end
end
