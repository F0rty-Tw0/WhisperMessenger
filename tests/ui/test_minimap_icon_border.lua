-- The minimap button wears the full ring over its dark circle, tinted to the
-- theme accent unless the themed setting keeps it gold, and takes it off with
-- the border setting.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local IconBorder = require("WhisperMessenger.UI.ToggleIcon.IconBorder")

local RING_PATH = "Interface\\AddOns\\WhisperMessenger\\Media\\ring_gold.png"
local WHITE = { 1, 1, 1, 1 }

local function createIcon(options)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Minimap", nil)
  parent:SetSize(140, 140)
  options = options or {}
  options.parent = parent

  return MinimapIcon.Create(factory, options)
end

local function near(a, b)
  return math.abs(a - b) < 0.001
end

local function centeredOn(texture, frame)
  local p = texture.point or {}

  return p[1] == "CENTER" and p[2] == frame and p[3] == "CENTER" and p[4] == 0 and p[5] == 0
end

local function sameColor(color, expected)
  return type(color) == "table"
    and color[1] == expected[1]
    and color[2] == expected[2]
    and color[3] == expected[3]
    and (color[4] or 1) == (expected[4] or 1)
end

local function constant(value)
  return function()
    return value
  end
end

return function()
  Theme.SetPreset("wow_default")

  -- test_minimap_wears_the_full_ring_by_default
  do
    local name = "test_minimap_wears_the_full_ring_by_default"
    local icon = createIcon()
    local ring = icon.ring
    local layer, sublevel = ring:GetDrawLayer()
    assert(ring.shown == true, name .. ": ring shown")
    assert(ring.texturePath == RING_PATH, name .. ": ring texture")
    assert(layer == "OVERLAY" and sublevel == -1, name .. ": ring over the button, got " .. tostring(layer) .. " " .. tostring(sublevel))
    assert(near(ring.width, 30), name .. ": ring at button size, got " .. tostring(ring.width))
    assert(centeredOn(ring, icon.frame), name .. ": ring centered")
  end

  -- test_minimap_bubbles_shrink_inside_the_ring
  do
    local icon = createIcon()
    assert(icon.iconTex.width == 21, "test_minimap_bubbles_shrink_inside_the_ring: bubbles at 0.7, got " .. tostring(icon.iconTex.width))
  end

  -- test_minimap_circle_stays_inside_the_ring
  do
    local name = "test_minimap_circle_stays_inside_the_ring"
    local icon = createIcon()
    assert(near(icon.background.width, 30 * IconBorder.FULL_RING_FACE_RATIO), name .. ": circle at mid-band, got " .. tostring(icon.background.width))
    assert(centeredOn(icon.background, icon.frame), name .. ": circle centered")
  end

  -- test_minimap_circle_fills_the_button_with_border_off
  do
    local icon = createIcon({ getIconBorder = constant(false) })
    assert(icon.background.allPoints == icon.frame, "test_minimap_circle_fills_the_button_with_border_off: circle fills the button")
  end

  -- test_minimap_ring_takes_the_accent_by_default
  do
    local name = "test_minimap_ring_takes_the_accent_by_default"
    local icon = createIcon()
    assert(icon.ring.desaturated == true, name .. ": ring desaturated")
    assert(sameColor(icon.ring.vertexColor, Theme.COLORS.accent), name .. ": ring takes the accent")
  end

  -- test_minimap_gold_ring_when_not_themed
  do
    local name = "test_minimap_gold_ring_when_not_themed"
    local icon = createIcon({ getIconBorderThemed = constant(false) })
    assert(icon.ring.desaturated == false, name .. ": ring keeps its gold")
    assert(sameColor(icon.ring.vertexColor, WHITE), name .. ": ring untinted")
  end

  -- test_minimap_border_off_shows_no_ring
  do
    local name = "test_minimap_border_off_shows_no_ring"
    local icon = createIcon({ getIconBorder = constant(false) })
    assert(icon.ring.shown == false, name .. ": ring hidden")
    assert(icon.iconTex.width == 27, name .. ": bubbles back at 0.9, got " .. tostring(icon.iconTex.width))
  end

  -- test_minimap_border_setting_applies_on_refresh
  do
    local name = "test_minimap_border_setting_applies_on_refresh"
    local on = true
    local icon = createIcon({
      getIconBorder = function()
        return on
      end,
    })

    on = false
    icon.refreshTheme()
    assert(icon.ring.shown == false, name .. ": ring hidden after off")
    assert(icon.iconTex.width == 27, name .. ": bubbles at 0.9 after off")
    assert(icon.background.allPoints == icon.frame, name .. ": circle fills the button after off")

    on = true
    icon.refreshTheme()
    assert(icon.ring.shown == true, name .. ": ring shown after on")
    assert(icon.iconTex.width == 21, name .. ": bubbles at 0.7 after on")
    assert(near(icon.background.width, 30 * IconBorder.FULL_RING_FACE_RATIO), name .. ": circle inside the ring after on")
  end

  -- test_minimap_ring_follows_the_theme
  do
    local name = "test_minimap_ring_follows_the_theme"
    Theme.SetPreset("elvui_dark")
    local icon = createIcon()

    Theme.SetPreset("plumber_warm")
    icon.refreshTheme()
    assert(sameColor(icon.ring.vertexColor, Theme.COLORS.accent), name .. ": ring takes the new accent")
    assert(not sameColor(icon.ring.vertexColor, { 0.34, 0.51, 0.90 }), name .. ": not ElvUI's accent")
    Theme.SetPreset("wow_default")
  end

  -- test_minimap_theme_change_keeps_a_hidden_ring_hidden
  do
    local icon = createIcon({ getIconBorder = constant(false) })

    Theme.SetPreset("plumber_warm")
    icon.refreshTheme()
    assert(icon.ring.shown == false, "test_minimap_theme_change_keeps_a_hidden_ring_hidden: ring still hidden")
    Theme.SetPreset("wow_default")
  end

  -- test_minimap_hover_leaves_the_ring_alone
  do
    local name = "test_minimap_hover_leaves_the_ring_alone"
    local icon = createIcon()
    local width = icon.ring.width
    local color = icon.ring.vertexColor

    icon.frame:GetScript("OnEnter")(icon.frame)
    icon.frame:GetScript("OnLeave")(icon.frame)
    assert(icon.ring.shown == true, name .. ": ring still shown")
    assert(icon.ring.width == width, name .. ": ring size unchanged")
    assert(sameColor(icon.ring.vertexColor, color), name .. ": ring color unchanged")
  end

  -- test_minimap_has_no_square_frame
  do
    local name = "test_minimap_has_no_square_frame"
    local icon = createIcon()
    assert(icon.squareFrame == nil, name .. ": no square frame field")
    for _, child in ipairs(icon.frame.children or {}) do
      assert(child.texturePath ~= IconBorder.SQUARE_FRAME_TEXTURE, name .. ": no square frame texture")
    end
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
