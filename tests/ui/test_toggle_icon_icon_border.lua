-- IconBorder owns the gold ring and square frame and paints one of four looks.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local IconBorder = require("WhisperMessenger.UI.ToggleIcon.IconBorder")

local function build(withSquareFrame, withFace)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Button", nil, nil)
  frame:SetSize(42, 42)
  local glyph = frame:CreateTexture(nil, "ARTWORK")
  local face = nil
  if withFace then
    face = frame:CreateTexture(nil, "BACKGROUND")
    face:SetAllPoints(frame)
  end
  local border = IconBorder.Create(frame, { glyph = glyph, glyphRatio = 0.9, squareFrame = withSquareFrame, face = face })
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

local WHITE = { 1, 1, 1, 1 }

do
  local function test_textures_point_at_the_shipped_art()
    assert(IconBorder.RING_TEXTURE == "Interface\\AddOns\\WhisperMessenger\\Media\\ring_gold.png")
    assert(IconBorder.SQUARE_FRAME_TEXTURE == "Interface\\AddOns\\WhisperMessenger\\Media\\frame_gold_square.png")
  end
  test_textures_point_at_the_shipped_art()
end

do
  local function test_look_for_maps_each_state_to_one_look()
    assert(IconBorder.LookFor(false, true, true) == "rim")
    assert(IconBorder.LookFor(false, false, true) == "ring")
    assert(IconBorder.LookFor(true, true, true) == "square")
    assert(IconBorder.LookFor(true, false, true) == "square")
    assert(IconBorder.LookFor(false, true, false) == "none")
    assert(IconBorder.LookFor(false, false, false) == "none")
    assert(IconBorder.LookFor(true, true, false) == "none")
    assert(IconBorder.LookFor(true, false, false) == "none")
  end
  test_look_for_maps_each_state_to_one_look()
end

do
  local function test_is_on_reads_a_missing_getter_as_on()
    assert(IconBorder.IsOn(nil) == true)
    assert(IconBorder.IsOn(function() end) == true)
    assert(IconBorder.IsOn(function()
      return true
    end) == true)
    assert(IconBorder.IsOn(function()
      return false
    end) == false)
  end
  test_is_on_reads_a_missing_getter_as_on()
end

do
  local function test_ring_and_frame_start_hidden()
    local border, frame = build(true)
    assert(border.ring.shown == false)
    assert(border.ring.texturePath == IconBorder.RING_TEXTURE)
    assert(border.squareFrame.shown == false)
    assert(border.squareFrame.texturePath == IconBorder.SQUARE_FRAME_TEXTURE)
    assert(border.squareFrame.allPoints == frame)
  end
  test_ring_and_frame_start_hidden()
end

do
  local function test_rim_sits_under_the_circle()
    local border, frame, glyph = build(false)
    border.paint("rim", false)
    local ring = border.ring
    assert(ring.shown == true)
    assert(select(1, ring:GetDrawLayer()) == "BACKGROUND")
    assert(select(2, ring:GetDrawLayer()) == -1)
    assert(near(ring.width, 48.3) and near(ring.height, 48.3))
    assert(centeredOn(ring, frame))
    assert(glyph.width == 37)
  end
  test_rim_sits_under_the_circle()
end

do
  local function test_full_ring_sits_over_the_circle()
    local border, frame, glyph = build(false)
    border.paint("ring", false)
    local ring = border.ring
    assert(ring.shown == true)
    assert(select(1, ring:GetDrawLayer()) == "OVERLAY")
    assert(select(2, ring:GetDrawLayer()) == -1)
    assert(near(ring.width, 42))
    assert(centeredOn(ring, frame))
    assert(glyph.width == 29)
  end
  test_full_ring_sits_over_the_circle()
end

do
  local function test_square_frame_covers_the_button()
    local border, _frame, glyph = build(true)
    border.paint("square", false)
    assert(border.squareFrame.shown == true)
    assert(border.squareFrame.drawLayer == "OVERLAY")
    assert(border.squareFrame.drawSublevel == -1)
    assert(border.ring.shown == false)
    assert(glyph.width == 37)
  end
  test_square_frame_covers_the_button()
end

do
  local function test_none_shows_no_border()
    local border, _frame, glyph = build(true)
    border.paint("none", true)
    assert(border.ring.shown == false)
    assert(border.squareFrame.shown == false)
    assert(glyph.width == 37)
  end
  test_none_shows_no_border()
end

do
  local function test_themed_border_takes_the_accent()
    local border = build(true)
    border.paint("ring", true)
    assert(border.ring.desaturated == true)
    assert(sameColor(border.ring.vertexColor, Theme.COLORS.accent))
    border.paint("square", true)
    assert(border.squareFrame.desaturated == true)
    assert(sameColor(border.squareFrame.vertexColor, Theme.COLORS.accent))
  end
  test_themed_border_takes_the_accent()
end

do
  local function test_gold_border_keeps_the_art_colors()
    local border = build(true)
    border.paint("rim", true)
    border.paint("rim", false)
    assert(border.ring.desaturated == false)
    assert(sameColor(border.ring.vertexColor, WHITE))
    border.paint("square", true)
    border.paint("square", false)
    assert(border.squareFrame.desaturated == false)
    assert(sameColor(border.squareFrame.vertexColor, WHITE))
  end
  test_gold_border_keeps_the_art_colors()
end

do
  local function test_look_change_moves_the_ring_between_layers()
    local border, _frame, glyph = build(false)
    border.paint("rim", false)
    border.paint("ring", false)
    border.paint("rim", false)
    local ring = border.ring
    assert(select(1, ring:GetDrawLayer()) == "BACKGROUND")
    assert(select(2, ring:GetDrawLayer()) == -1)
    assert(near(ring.width, 48.3))
    assert(glyph.width == 37)
  end
  test_look_change_moves_the_ring_between_layers()
end

do
  local function test_paint_follows_a_resize()
    local border, frame, glyph = build(false)
    frame:SetSize(60, 60)
    border.paint("rim", false)
    assert(near(border.ring.width, 69))
    assert(glyph.width == 54)
    border.paint("ring", false)
    assert(near(border.ring.width, 60))
    assert(glyph.width == 42)
  end
  test_paint_follows_a_resize()
end

do
  local function test_without_square_frame_there_is_none()
    local border = build(nil)
    assert(border.squareFrame == nil)
    border.paint("square", true)
    assert(border.ring.shown == false)
  end
  test_without_square_frame_there_is_none()
end

do
  local function test_full_ring_shrinks_the_face_inside_the_band()
    local border, frame, _glyph, face = build(false, true)
    assert(face, "face made")
    border.paint("ring", false)
    assert(near(face.width, 42 * 0.89))
    assert(centeredOn(face, frame))
  end
  test_full_ring_shrinks_the_face_inside_the_band()
end

do
  local function test_other_looks_give_the_face_the_whole_button()
    local border, frame, _glyph, face = build(false, true)
    assert(face, "face made")
    border.paint("ring", false)
    border.paint("none", false)
    assert(face.allPoints == frame)
    border.paint("ring", false)
    border.paint("rim", false)
    assert(face.allPoints == frame)
  end
  test_other_looks_give_the_face_the_whole_button()
end

do
  local function test_without_face_paint_needs_none()
    local border = build(false)
    border.paint("ring", true)
  end
  test_without_face_paint_needs_none()
end
