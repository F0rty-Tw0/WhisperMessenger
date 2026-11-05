-- The round widget's ring follows setting toggles, theme changes and icon size
-- changes, and stays put through hover, press, pulse and idle gray.
local Theme = require("WhisperMessenger.UI.Theme")
local widget = require("tests.helpers.border_widget")
local Desaturation = require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local PulseGlow = require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")

local WHITE = { 1, 1, 1, 1 }

local function near(a, b)
  return math.abs(a - b) < 0.001
end

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function fire(icon, script)
  icon.frame:GetScript(script)(icon.frame)
end

local function ringSnapshot(ring)
  local color = ring.vertexColor or {}

  return { ring.shown, ring.drawLayer, ring.drawSublevel, ring.width, ring.desaturated, color[1], color[2], color[3], color[4] }
end

local function sameSnapshot(a, b)
  for i = 1, 9 do
    if a[i] ~= b[i] then
      return false, i
    end
  end

  return true
end

return function()
  Theme.SetPreset("wow_default")

  -- test_background_off_while_hovered_gives_the_full_ring
  do
    local state = {}
    local icon = widget(state)
    fire(icon, "OnEnter")
    state.background = false
    icon.refreshTheme()
    local layer = icon.ring:GetDrawLayer()
    assert(layer == "OVERLAY", "full ring over the button, got " .. tostring(layer))
    assert(near(icon.ring.width, 48.3), "full ring keeps the rim's outer size, got " .. tostring(icon.ring.width))
    assert(icon.label.width == 33, "bubbles at 0.7 of the ring, got " .. tostring(icon.label.width))
    assert(icon.hoverGlow.shown == true, "glow while hovered without the circle")
  end

  -- test_background_back_on_while_hovered_gives_the_rim_again
  do
    local state = { background = false }
    local icon = widget(state)
    fire(icon, "OnEnter")
    state.background = nil
    icon.refreshTheme()
    local layer = icon.ring:GetDrawLayer()
    assert(layer == "BACKGROUND", "rim under the circle again, got " .. tostring(layer))
    assert(near(icon.ring.width, 48.3), "rim size again, got " .. tostring(icon.ring.width))
    assert(icon.label.width == 37, "bubbles at 0.9 again, got " .. tostring(icon.label.width))
    assert(icon.hoverGlow.shown ~= true, "no glow with the circle")
  end

  -- test_border_toggle_applies_on_refresh
  do
    local state = {}
    local icon = widget(state)
    state.border = false
    icon.refreshTheme()
    assert(icon.ring.shown == false, "ring off")
    state.border = nil
    icon.refreshTheme()
    assert(icon.ring.shown == true, "ring back on")
  end

  -- test_themed_toggle_applies_on_refresh
  do
    local state = {}
    local icon = widget(state)
    state.themed = false
    icon.refreshTheme()
    assert(sameColor(icon.ring.vertexColor, WHITE) and icon.ring.desaturated == false, "gold when not themed")
    state.themed = nil
    icon.refreshTheme()
    assert(sameColor(icon.ring.vertexColor, Theme.COLORS.accent) and icon.ring.desaturated == true, "accent when themed")
  end

  -- test_theme_change_retints_the_ring
  do
    Theme.SetPreset("elvui_dark")
    local icon = widget({})
    Theme.SetPreset("plumber_warm")
    icon.refreshTheme()
    assert(sameColor(icon.ring.vertexColor, Theme.COLORS.accent), "ring in the new accent")
  end

  -- test_gold_ring_stays_gold_on_theme_change
  do
    Theme.SetPreset("elvui_dark")
    local icon = widget({ themed = false })
    Theme.SetPreset("plumber_warm")
    icon.refreshTheme()
    assert(sameColor(icon.ring.vertexColor, WHITE), "gold ring keeps its white vertex")
  end

  Theme.SetPreset("wow_default")

  -- test_icon_size_change_resizes_the_rim
  do
    local icon = widget({})
    icon.applyIconSize(60)
    assert(near(icon.ring.width, 69), "rim at 60 * 1.15, got " .. tostring(icon.ring.width))
    assert(icon.label.width == 54, "bubbles at 0.9, got " .. tostring(icon.label.width))
  end

  -- test_full_ring_follows_the_icon_size
  do
    local icon = widget({ background = false })
    icon.applyIconSize(60)
    assert(near(icon.ring.width, 69), "full ring at 60 * 1.15, got " .. tostring(icon.ring.width))
    assert(icon.label.width == 48, "bubbles at 0.7 of the ring, got " .. tostring(icon.label.width))
  end

  -- test_hover_glow_follows_the_full_ring_glyph_after_resize
  do
    local icon = widget({ background = false })
    fire(icon, "OnEnter")
    icon.applyIconSize(60)
    local expected = 48 * SquareLook.BUBBLE_GLOW_SCALE
    assert(
      near(icon.hoverGlow.width, expected),
      "test_hover_glow_follows_the_full_ring_glyph_after_resize: glow from the 0.7 glyph, got " .. tostring(icon.hoverGlow.width)
    )
  end

  -- test_hover_glow_follows_the_full_ring_glyph_after_square
  do
    local state = { shape = "square", background = false }
    local icon = widget(state)
    fire(icon, "OnEnter")
    state.shape = nil
    icon.refreshTheme()
    local expected = 33 * SquareLook.BUBBLE_GLOW_SCALE
    assert(
      near(icon.hoverGlow.width, expected),
      "test_hover_glow_follows_the_full_ring_glyph_after_square: glow from the 0.7 glyph, got " .. tostring(icon.hoverGlow.width)
    )
  end

  -- test_square_pulse_follows_the_square_glyph_after_full_ring
  do
    local state = { background = false }
    local icon = widget(state)
    state.shape = "square"
    icon.refreshTheme()
    local expected = 37 * SquareLook.BUBBLE_GLOW_SCALE
    assert(
      near(icon.pulseTexture.width, expected),
      "test_square_pulse_follows_the_square_glyph_after_full_ring: pulse from the 0.9 glyph, got " .. tostring(icon.pulseTexture.width)
    )
  end

  -- test_hover_press_pulse_and_idle_gray_leave_the_ring_alone
  do
    local icon = widget({ desaturated = true })
    icon.setUnreadCount(0)
    local before = ringSnapshot(icon.ring)
    local steps = {
      function()
        fire(icon, "OnEnter")
      end,
      function()
        fire(icon, "OnMouseDown")
      end,
      function()
        fire(icon, "OnMouseUp")
      end,
      function()
        fire(icon, "OnLeave")
      end,
      function()
        icon.setUnreadCount(3)
      end,
    }
    for index, step in ipairs(steps) do
      step()
      local same, field = sameSnapshot(before, ringSnapshot(icon.ring))
      assert(same, "ring changed at step " .. index .. ", field " .. tostring(field))
    end
  end

  -- test_circle_without_background_glows_on_hover
  do
    local icon = widget({ background = false })
    fire(icon, "OnEnter")
    assert(icon.hoverGlow.shown == true, "glow on hover without the circle")
  end

  -- test_bubbles_only_circle_keeps_round_pulse_and_light_gray
  do
    local icon = widget({ background = false, border = false, desaturated = true })
    icon.setUnreadCount(0)
    assert(sameColor(icon.accentGlyph.vertexColor, Desaturation.DESAT_BACK), "the circle's light gray")
    icon.setUnreadCount(2)
    local pulse = icon.pulseTexture
    assert(pulse.texturePath == PulseGlow.TEXTURE, "round pulse art, got " .. tostring(pulse.texturePath))
    assert(pulse.allPoints and pulse.allPoints.allPoints == icon.frame, "round pulse over the button")
    assert(icon.ring.shown == false, "no ring")
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
