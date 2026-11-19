-- The square's frame, fill, backdrop, mask and EllesmereUI effects sit on a
-- box 1.15x the button (IconBorder.RIM_SCALE, the circle ring's size),
-- centred on it; the button, bubbles, badge and pulse stay at 1.0x. With the
-- border off, and on the circle, the fill is back on the button.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Shapes = require("WhisperMessenger.UI.Helpers.Shapes")
local Shape = require("tests.helpers.toggle_icon_shape")
local withProfile = require("tests.helpers.ellesmere_profile")

local near = Shape.near

local function widget(state, factory)
  return Shape.iconWithShape(function()
    return state.shape or "square"
  end, {
    getIconBorder = function()
      return state.border
    end,
  }, factory or FakeUI.NewFactory({ masks = true }))
end

local function at(p, point, frame, x, y)
  return type(p) == "table" and p[1] == point and p[2] == frame and p[3] == point and near(p[4], x) and near(p[5], y)
end

return function()
  Theme.SetPreset("wow_default")

  -- test_square_frame_fill_backdrop_and_mask_on_the_box
  do
    local name = "test_square_frame_fill_backdrop_and_mask_on_the_box"
    local icon = widget({})
    assert(Shape.onBox(icon.squareFrame, icon.frame, 3.15), name .. ": frame")
    assert(Shape.onBox(icon.background, icon.frame, 3.15), name .. ": fill")
    assert(Shape.onBox(icon.squareBackdrop, icon.frame, 3.15), name .. ": backdrop")
    assert(Shape.onBox(icon.squareMask, icon.frame, 3.15), name .. ": mask")
    assert(icon.frame.width == 42, name .. ": button stays 42, got " .. tostring(icon.frame.width))
  end

  -- test_bubbles_badge_and_pulse_stay_at_button_size
  do
    local name = "test_bubbles_badge_and_pulse_stay_at_button_size"
    local icon = widget({})
    assert(icon.label.width == 37, name .. ": bubbles at 0.9 of 42, got " .. tostring(icon.label.width))
    assert(Shape.fillsWithSquareGlow(icon.pulseTexture, icon.frame), name .. ": pulse covers the button")
    local p = icon.badge.point
    assert(p[1] == "TOPRIGHT" and p[2] == icon.frame and p[3] == "TOPRIGHT" and p[4] == 6 and p[5] == 6, name .. ": badge on the button corner")
  end

  -- test_border_off_keeps_the_square_at_button_size
  do
    local name = "test_border_off_keeps_the_square_at_button_size"
    local icon = widget({ border = false })
    assert(Shape.coversButton(icon.background, icon.frame), name .. ": fill")
    assert(Shape.coversButton(icon.squareBackdrop, icon.frame), name .. ": backdrop")
    assert(Shape.coversButton(icon.squareMask, icon.frame), name .. ": mask")
  end

  -- test_circle_puts_the_fill_back_on_the_button
  do
    local name = "test_circle_puts_the_fill_back_on_the_button"
    local state = {}
    local icon = widget(state)
    state.shape = "circle"
    icon.refreshTheme()
    assert(Shape.coversButton(icon.background, icon.frame), name .. ": circle fill on the button")
    assert(Shape.coversButton(icon.squareMask, icon.frame), name .. ": mask on the button")
    state.shape = "square"
    icon.refreshTheme()
    assert(Shape.onBox(icon.background, icon.frame, 3.15), name .. ": square fill back on the box")
  end

  -- test_box_follows_the_icon_size
  do
    local name = "test_box_follows_the_icon_size"
    local icon = widget({})
    icon.applyIconSize(60)
    assert(Shape.onBox(icon.squareFrame, icon.frame, 4.5), name .. ": frame")
    assert(Shape.onBox(icon.background, icon.frame, 4.5), name .. ": fill")
    assert(Shape.onBox(icon.squareMask, icon.frame, 4.5), name .. ": mask")
    assert(icon.frame.width == 60, name .. ": button at 60, got " .. tostring(icon.frame.width))
  end

  -- test_box_without_masks
  do
    local name = "test_box_without_masks"
    local icon = widget({}, FakeUI.NewFactory())
    assert(icon.squareMask == nil, name .. ": no mask")
    assert(Shape.onBox(icon.background, icon.frame, 3.15), name .. ": fill still on the box")
  end

  -- test_ellesmere_effects_sit_on_the_box
  withProfile({ highlightTextureType = 4, pushedTextureType = 5, pushedBorderSize = 2 }, function()
    local name = "test_ellesmere_effects_sit_on_the_box"
    local icon = widget({})
    local frame = icon.frame
    local d = Shapes.pixelSize(frame)
    local o = 3.15
    local hover = icon.squareHover.points
    assert(#hover == 2, name .. ": hover fill anchored twice")
    assert(at(hover[1], "TOPLEFT", frame, d - o, o - d), name .. ": hover fill top-left inset from the box")
    assert(at(hover[2], "BOTTOMRIGHT", frame, o - d, d - o), name .. ": hover fill bottom-right inset from the box")
    local top = icon.squarePushedEdges.top.points
    assert(#top == 2 and at(top[1], "TOPLEFT", frame, -o, o) and at(top[2], "TOPRIGHT", frame, o, o), name .. ": pushed top edge along the box")
    local right = icon.squarePushedEdges.right.points
    assert(at(right[2], "BOTTOMRIGHT", frame, o, -o), name .. ": pushed right edge down to the box corner")
  end)

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
