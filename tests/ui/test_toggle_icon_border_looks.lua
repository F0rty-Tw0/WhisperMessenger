-- The round widget wears the ring: a thin rim under its circle, or the full
-- ring over the button when the circle is off. Tinted to the theme accent, or
-- gold when the themed setting is off; the border setting takes it off.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local widget = require("tests.helpers.border_widget")

local WHITE = { 1, 1, 1, 1 }

local function near(a, b)
  return math.abs(a - b) < 0.001
end

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function centeredOn(texture, frame)
  local p = texture.point or {}

  return p[1] == "CENTER" and p[2] == frame and p[3] == "CENTER" and p[4] == 0 and p[5] == 0
end

return function()
  Theme.SetPreset("wow_default")

  -- test_circle_with_background_wears_the_rim
  do
    local icon = widget({})
    local ring = icon.ring
    local layer, sublevel = ring:GetDrawLayer()
    assert(ring.shown == true, "ring shown")
    assert(layer == "BACKGROUND" and sublevel == -1, "rim under the circle, got " .. tostring(layer) .. " " .. tostring(sublevel))
    assert((icon.background.drawSublevel or 0) > -1, "circle drawn over the ring")
    assert(near(ring.width, 48.3), "rim past the circle, got " .. tostring(ring.width))
    assert(centeredOn(ring, icon.frame), "ring centered on the button")
    assert(icon.label.width == 37, "bubbles at 0.9, got " .. tostring(icon.label.width))
    assert(icon.background.shown == true, "circle shown")
    assert(icon.squareFrame.shown == false, "no square frame on the circle")
  end

  -- test_circle_without_background_wears_the_full_ring
  do
    local icon = widget({ background = false })
    local ring = icon.ring
    local layer, sublevel = ring:GetDrawLayer()
    assert(ring.shown == true, "ring shown")
    assert(layer == "OVERLAY" and sublevel == -1, "full ring over the button, got " .. tostring(layer) .. " " .. tostring(sublevel))
    assert(near(ring.width, 48.3), "ring at the rim's outer size, got " .. tostring(ring.width))
    assert(icon.label.width == 33, "bubbles at 0.7 of the ring, got " .. tostring(icon.label.width))
    assert(icon.background.shown == false, "circle hidden")
  end

  -- test_circle_without_background_outlines_the_bubbles
  do
    local icon = widget({ background = false })
    assert(icon.glyphOutline.shown == true, "bubbles outlined without the circle")
  end

  -- test_circle_border_off_has_no_ring
  do
    local icon = widget({ border = false })
    assert(icon.ring.shown == false, "no ring")
    assert(icon.label.width == 37, "bubbles at 0.9, got " .. tostring(icon.label.width))
    assert(icon.background.shown == true, "circle shown")
  end

  -- test_circle_bubbles_only_without_background_and_border
  do
    local icon = widget({ background = false, border = false })
    assert(icon.ring.shown == false, "no ring")
    assert(icon.background.shown == false, "no circle")
    assert(icon.label.width == 37, "bubbles at 0.9, got " .. tostring(icon.label.width))
  end

  -- test_rim_and_full_ring_take_the_accent
  do
    for _, background in ipairs({ true, false }) do
      local icon = widget({ background = background })
      assert(icon.ring.desaturated == true, "ring desaturated for the tint, background " .. tostring(background))
      assert(sameColor(icon.ring.vertexColor, Theme.COLORS.accent), "ring in the accent, background " .. tostring(background))
    end
  end

  -- test_rim_and_full_ring_stay_gold_when_not_themed
  do
    for _, background in ipairs({ true, false }) do
      local icon = widget({ background = background, themed = false })
      assert(icon.ring.desaturated == false, "gold not desaturated, background " .. tostring(background))
      assert(sameColor(icon.ring.vertexColor, WHITE), "gold under a white vertex, background " .. tostring(background))
    end
  end

  -- test_missing_border_getters_mean_on
  do
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {})
    assert(icon.ring.shown == true, "ring shown without getters")
    assert(icon.ring.desaturated == true, "themed without getters")
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
