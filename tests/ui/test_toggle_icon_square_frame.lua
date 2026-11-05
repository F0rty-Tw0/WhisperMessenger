-- The square widget wears the square frame, on top of the slot background or
-- without it, and the border setting takes it off. Tinted to the theme accent,
-- or gold when not themed.
local Theme = require("WhisperMessenger.UI.Theme")
local borderWidget = require("tests.helpers.border_widget")
local IconBorder = require("WhisperMessenger.UI.ToggleIcon.IconBorder")
local SquareLook = require("WhisperMessenger.UI.ToggleIcon.SquareLook")

local WHITE = { 1, 1, 1, 1 }

local function near(a, b)
  return math.abs(a - b) < 0.001
end

local function sameColor(a, b)
  return type(a) == "table" and type(b) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function widget(state)
  return borderWidget(state, "square")
end

local function borderTextures(frame)
  local found = {}
  for _, child in ipairs(frame.children or {}) do
    if child.frameType == "Texture" and child.drawLayer == "BORDER" then
      table.insert(found, child)
    end
  end

  return found
end

return function()
  Theme.SetPreset("wow_default")

  -- test_square_with_background_wears_the_frame
  do
    local icon = widget({})
    local frame = icon.squareFrame
    assert(frame.shown == true, "frame shown")
    assert(frame.texturePath == IconBorder.SQUARE_FRAME_TEXTURE, "gold square frame art, got " .. tostring(frame.texturePath))
    assert(
      frame.drawLayer == "OVERLAY" and frame.drawSublevel == -1,
      "frame at OVERLAY -1, got " .. tostring(frame.drawLayer) .. " " .. tostring(frame.drawSublevel)
    )
    assert(frame.allPoints == icon.frame, "frame covers the button")
    assert(icon.ring.shown == false, "no ring on the square")
    assert(icon.label.width == 37, "bubbles at 0.9, got " .. tostring(icon.label.width))
    assert(icon.background.texturePath == SquareLook.SQUARE_TEXTURE and icon.background.shown == true, "slot background shown")
  end

  -- test_square_without_background_still_wears_the_frame
  do
    local icon = widget({ background = false })
    assert(icon.squareFrame.shown == true, "frame shown without the background")
    assert(icon.background.shown == false, "background hidden")
  end

  -- test_square_border_off_has_no_frame
  do
    local icon = widget({ border = false })
    assert(icon.squareFrame.shown == false, "no frame")
    assert(icon.ring.shown == false, "no ring")
  end

  -- test_square_bubbles_only_without_background_and_border
  do
    local icon = widget({ background = false, border = false })
    assert(icon.squareFrame.shown == false, "no frame")
    assert(icon.background.shown == false, "no background")
    assert(icon.glyphOutline.shown == true, "bubbles outlined")
  end

  -- test_square_has_no_thin_edge
  do
    local icon = widget({})
    local edges = borderTextures(icon.frame)
    assert(#edges == 0, "no BORDER-layer edge textures, found " .. #edges)
  end

  -- test_square_frame_takes_the_accent
  do
    local icon = widget({})
    assert(icon.squareFrame.desaturated == true, "frame desaturated for the tint")
    assert(sameColor(icon.squareFrame.vertexColor, Theme.COLORS.accent), "frame in the accent")
  end

  -- test_square_frame_stays_gold_when_not_themed
  do
    local icon = widget({ themed = false })
    assert(icon.squareFrame.desaturated == false, "gold not desaturated")
    assert(sameColor(icon.squareFrame.vertexColor, WHITE), "gold under a white vertex")
  end

  -- test_hover_and_press_fills_draw_over_the_frame
  do
    local icon = widget({})
    local frameSublevel = icon.squareFrame.drawSublevel
    assert(icon.squareHover.drawLayer == "OVERLAY" and icon.squareHover.drawSublevel == 1, "hover fill at OVERLAY 1")
    assert(icon.squarePushed.drawLayer == "OVERLAY" and icon.squarePushed.drawSublevel == 2, "pushed fill at OVERLAY 2")
    assert(icon.squareHover.drawSublevel > frameSublevel, "hover fill above the frame")
    assert(icon.squarePushed.drawSublevel > frameSublevel, "pushed fill above the frame")
    icon.frame:GetScript("OnEnter")(icon.frame)
    icon.frame:GetScript("OnMouseDown")(icon.frame)
    assert(icon.squareHover.shown == true, "hover fill shown")
    assert(icon.squarePushed.shown == true, "pushed fill shown")
    assert(icon.squareFrame.shown == true, "frame stays under the fills")
  end

  -- test_shape_change_swaps_ring_and_frame
  do
    local state = { shape = "circle" }
    local icon = widget(state)
    assert(icon.ring.shown == true and icon.squareFrame.shown == false, "rim on the circle")
    state.shape = "square"
    icon.refreshTheme()
    assert(icon.ring.shown == false, "ring hidden on the square")
    assert(icon.squareFrame.shown == true, "frame shown on the square")
    state.shape = "circle"
    icon.refreshTheme()
    local layer = icon.ring:GetDrawLayer()
    assert(icon.ring.shown == true and layer == "BACKGROUND", "rim back under the circle")
    assert(near(icon.ring.width, 48.3), "rim past the circle, got " .. tostring(icon.ring.width))
    assert(icon.squareFrame.shown == false, "frame hidden on the circle")
  end

  -- test_square_frame_follows_the_icon_size
  do
    local icon = widget({})
    icon.applyIconSize(60)
    assert(icon.squareFrame.allPoints == icon.frame, "frame still covers the button")
    assert(icon.label.width == 54, "bubbles at 0.9 of 60, got " .. tostring(icon.label.width))
  end

  Theme.SetPreset(Theme.DEFAULT_PRESET)
end
