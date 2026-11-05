-- IconBorder owns the ring and square frame and paints one of four looks.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local IconBorder = require("WhisperMessenger.UI.ToggleIcon.IconBorder")

local WHITE = { 1, 1, 1, 1 }

local function build(withSquareFrame, withFace, ringScale)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Button", nil, nil)
  frame:SetSize(42, 42)
  local glyph = frame:CreateTexture(nil, "ARTWORK")
  local face = nil
  if withFace then
    face = frame:CreateTexture(nil, "BACKGROUND")
    face:SetAllPoints(frame)
  end
  local border = IconBorder.Create(frame, {
    glyph = glyph,
    glyphRatio = 0.9,
    withSquareFrame = withSquareFrame,
    face = face,
    ringScale = ringScale,
  })

  return border, frame, glyph, face
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

return function()
  -- test_textures_point_at_the_shipped_art
  do
    local name = "test_textures_point_at_the_shipped_art"
    assert(IconBorder.RING_TEXTURE == "Interface\\AddOns\\WhisperMessenger\\Media\\ring_gold.png", name .. ": ring art")
    assert(IconBorder.SQUARE_FRAME_TEXTURE == "Interface\\AddOns\\WhisperMessenger\\Media\\frame_gold_square.png", name .. ": square frame art")
  end

  -- test_look_for_maps_each_state_to_one_look
  do
    local name = "test_look_for_maps_each_state_to_one_look"
    assert(IconBorder.LookFor(false, true, true) == "rim", name .. ": circle with background")
    assert(IconBorder.LookFor(false, false, true) == "ring", name .. ": circle without background")
    assert(IconBorder.LookFor(true, true, true) == "square", name .. ": square with background")
    assert(IconBorder.LookFor(true, false, true) == "square", name .. ": square without background")
    assert(IconBorder.LookFor(false, true, false) == "none", name .. ": border off, circle with background")
    assert(IconBorder.LookFor(false, false, false) == "none", name .. ": border off, circle without background")
    assert(IconBorder.LookFor(true, true, false) == "none", name .. ": border off, square with background")
    assert(IconBorder.LookFor(true, false, false) == "none", name .. ": border off, square without background")
  end

  -- test_ring_and_frame_start_hidden
  do
    local name = "test_ring_and_frame_start_hidden"
    local border, frame = build(true)
    assert(border.ring.shown == false, name .. ": ring hidden")
    assert(border.ring.texturePath == IconBorder.RING_TEXTURE, name .. ": ring art")
    assert(border.squareFrame.shown == false, name .. ": square frame hidden")
    assert(border.squareFrame.texturePath == IconBorder.SQUARE_FRAME_TEXTURE, name .. ": square frame art")
    assert(border.squareFrame.allPoints == frame, name .. ": square frame covers the button")
  end

  -- test_rim_sits_under_the_circle
  do
    local name = "test_rim_sits_under_the_circle"
    local border, frame, glyph = build(false)
    border.paint("rim", false)
    local ring = border.ring
    local layer, sublevel = ring:GetDrawLayer()
    assert(ring.shown == true, name .. ": ring shown")
    assert(layer == "BACKGROUND", name .. ": layer, got " .. tostring(layer))
    assert(sublevel == -1, name .. ": sublevel, got " .. tostring(sublevel))
    assert(near(ring.width, 48.3) and near(ring.height, 48.3), name .. ": size, got " .. tostring(ring.width))
    assert(centeredOn(ring, frame), name .. ": centered")
    assert(glyph.width == 37, name .. ": glyph at 0.9, got " .. tostring(glyph.width))
  end

  -- test_full_ring_sits_over_the_circle
  do
    local name = "test_full_ring_sits_over_the_circle"
    local border, frame, glyph = build(false)
    border.paint("ring", false)
    local ring = border.ring
    local layer, sublevel = ring:GetDrawLayer()
    assert(ring.shown == true, name .. ": ring shown")
    assert(layer == "OVERLAY", name .. ": layer, got " .. tostring(layer))
    assert(sublevel == -1, name .. ": sublevel, got " .. tostring(sublevel))
    assert(near(ring.width, 42), name .. ": size, got " .. tostring(ring.width))
    assert(centeredOn(ring, frame), name .. ": centered")
    assert(glyph.width == 29, name .. ": glyph at 0.7, got " .. tostring(glyph.width))
  end

  -- test_ring_scale_grows_the_full_ring_and_its_bubbles
  do
    local name = "test_ring_scale_grows_the_full_ring_and_its_bubbles"
    local border, frame, glyph = build(false, false, IconBorder.RIM_SCALE)
    border.paint("ring", false)
    local ring = border.ring
    assert(ring:GetDrawLayer() == "OVERLAY", name .. ": over the button")
    assert(near(ring.width, 48.3) and near(ring.height, 48.3), name .. ": size, got " .. tostring(ring.width))
    assert(centeredOn(ring, frame), name .. ": centered")
    assert(glyph.width == 33, name .. ": glyph at 0.7 of the ring, got " .. tostring(glyph.width))
  end

  -- test_ring_scale_leaves_the_rim_alone
  do
    local name = "test_ring_scale_leaves_the_rim_alone"
    local border, _frame, glyph = build(false, false, IconBorder.RIM_SCALE)
    border.paint("rim", false)
    assert(near(border.ring.width, 48.3), name .. ": size, got " .. tostring(border.ring.width))
    assert(glyph.width == 37, name .. ": glyph at 0.9, got " .. tostring(glyph.width))
  end

  -- test_square_frame_covers_the_button
  do
    local name = "test_square_frame_covers_the_button"
    local border, _frame, glyph = build(true)
    border.paint("square", false)
    assert(border.squareFrame.shown == true, name .. ": square frame shown")
    assert(border.squareFrame.drawLayer == "OVERLAY", name .. ": layer, got " .. tostring(border.squareFrame.drawLayer))
    assert(border.squareFrame.drawSublevel == -1, name .. ": sublevel, got " .. tostring(border.squareFrame.drawSublevel))
    assert(border.ring.shown == false, name .. ": ring hidden")
    assert(glyph.width == 37, name .. ": glyph at 0.9, got " .. tostring(glyph.width))
  end

  -- test_none_shows_no_border
  do
    local name = "test_none_shows_no_border"
    local border, _frame, glyph = build(true)
    border.paint("none", true)
    assert(border.ring.shown == false, name .. ": ring hidden")
    assert(border.squareFrame.shown == false, name .. ": square frame hidden")
    assert(glyph.width == 37, name .. ": glyph at 0.9, got " .. tostring(glyph.width))
  end

  -- test_themed_border_takes_the_accent
  do
    local name = "test_themed_border_takes_the_accent"
    local border = build(true)
    border.paint("ring", true)
    assert(border.ring.desaturated == true, name .. ": ring desaturated")
    assert(sameColor(border.ring.vertexColor, Theme.COLORS.accent), name .. ": ring in the accent")
    border.paint("square", true)
    assert(border.squareFrame.desaturated == true, name .. ": square frame desaturated")
    assert(sameColor(border.squareFrame.vertexColor, Theme.COLORS.accent), name .. ": square frame in the accent")
  end

  -- test_gold_border_keeps_the_art_colors
  do
    local name = "test_gold_border_keeps_the_art_colors"
    local border = build(true)
    border.paint("rim", true)
    border.paint("rim", false)
    assert(border.ring.desaturated == false, name .. ": ring not desaturated")
    assert(sameColor(border.ring.vertexColor, WHITE), name .. ": ring untinted")
    border.paint("square", true)
    border.paint("square", false)
    assert(border.squareFrame.desaturated == false, name .. ": square frame not desaturated")
    assert(sameColor(border.squareFrame.vertexColor, WHITE), name .. ": square frame untinted")
  end

  -- test_look_change_moves_the_ring_between_layers
  do
    local name = "test_look_change_moves_the_ring_between_layers"
    local border, _frame, glyph = build(false)
    border.paint("rim", false)
    border.paint("ring", false)
    border.paint("rim", false)
    local ring = border.ring
    local layer, sublevel = ring:GetDrawLayer()
    assert(layer == "BACKGROUND", name .. ": layer, got " .. tostring(layer))
    assert(sublevel == -1, name .. ": sublevel, got " .. tostring(sublevel))
    assert(near(ring.width, 48.3), name .. ": size, got " .. tostring(ring.width))
    assert(glyph.width == 37, name .. ": glyph at 0.9, got " .. tostring(glyph.width))
  end

  -- test_paint_follows_a_resize
  do
    local name = "test_paint_follows_a_resize"
    local border, frame, glyph = build(false)
    frame:SetSize(60, 60)
    border.paint("rim", false)
    assert(near(border.ring.width, 69), name .. ": rim size, got " .. tostring(border.ring.width))
    assert(glyph.width == 54, name .. ": rim glyph, got " .. tostring(glyph.width))
    border.paint("ring", false)
    assert(near(border.ring.width, 60), name .. ": full ring size, got " .. tostring(border.ring.width))
    assert(glyph.width == 42, name .. ": full ring glyph, got " .. tostring(glyph.width))
  end

  -- test_without_square_frame_there_is_none
  do
    local name = "test_without_square_frame_there_is_none"
    local border = build(nil)
    assert(border.squareFrame == nil, name .. ": no square frame")
    border.paint("square", true)
    assert(border.ring.shown == false, name .. ": ring hidden")
  end

  -- test_full_ring_shrinks_the_face_inside_the_band
  do
    local name = "test_full_ring_shrinks_the_face_inside_the_band"
    local border, frame, _glyph, face = build(false, true)
    assert(face, name .. ": face made")
    border.paint("ring", false)
    assert(near(face.width, 42 * 0.89), name .. ": face size, got " .. tostring(face.width))
    assert(centeredOn(face, frame), name .. ": face centered")
  end

  -- test_other_looks_give_the_face_the_whole_button
  do
    local name = "test_other_looks_give_the_face_the_whole_button"
    local border, frame, _glyph, face = build(false, true)
    assert(face, name .. ": face made")
    border.paint("ring", false)
    border.paint("none", false)
    assert(face.allPoints == frame, name .. ": none")
    border.paint("ring", false)
    border.paint("rim", false)
    assert(face.allPoints == frame, name .. ": rim")
  end

  -- test_without_face_paint_needs_none
  do
    local border = build(false)
    border.paint("ring", true)
  end
end
