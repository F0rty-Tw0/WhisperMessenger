local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Shapes = require("WhisperMessenger.UI.Helpers.Shapes")

local function approx(a, b)
  return math.abs(a - b) < 0.0001
end

-- Frame whose textures expose the Retail snapping API so the test can see it.
local function newFrame(scale)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  frame:SetScale(scale)
  local createTexture = frame.CreateTexture
  rawset(frame, "CreateTexture", function(self, ...)
    local texture = createTexture(self, ...)
    function texture:SetSnapToPixelGrid(value)
      self.snapToPixelGrid = value
    end
    function texture:SetTexelSnappingBias(value)
      self.texelSnappingBias = value
    end
    return texture
  end)
  return frame
end

local function lastPointY(region, anchor)
  local y = 0
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == anchor then
      y = pt[5]
    end
  end
  return y
end

return function()
  local previousPreset = Theme.GetPreset()
  local previousPhysical = _G.GetPhysicalScreenSize

  -- test_pixel_size_uses_physical_height_and_effective_scale
  rawset(_G, "GetPhysicalScreenSize", function()
    return 2560, 1440
  end)
  assert(approx(Shapes.pixelSize(newFrame(0.8)), 768 / 1440 / 0.8), "one physical pixel at 1440p, scale 0.8")

  -- test_pixel_size_falls_back_to_1080
  rawset(_G, "GetPhysicalScreenSize", function()
    return 0, 0
  end)
  assert(approx(Shapes.pixelSize(newFrame(1)), 768 / 1080), "fallback physical height 1080")
  rawset(_G, "GetPhysicalScreenSize", nil)
  assert(approx(Shapes.pixelSize(newFrame(1)), 768 / 1080), "missing API falls back to 1080")

  -- test_border_edges_are_at_least_one_physical_pixel
  rawset(_G, "GetPhysicalScreenSize", function()
    return 2560, 1440
  end)
  Theme.SetPreset("wow_default")
  do
    local frame = newFrame(1)
    local px = 768 / 1440
    local border = assert(Shapes.createBorderBox(frame, { 1, 1, 1, 0.08 }, 1, "BORDER"))
    for _, side in ipairs({ "top", "bottom" }) do
      assert(border[side].height >= px - 0.0001, side .. " edge is at least one physical pixel")
    end
    for _, side in ipairs({ "left", "right" }) do
      assert(border[side].width >= px - 0.0001, side .. " edge is at least one physical pixel")
    end
  end

  -- test_side_strips_span_the_full_box_height
  -- An inset side strip leaves a seam at each corner whenever the engine
  -- rounds the top/bottom strips and the inset differently; full-height
  -- sides always meet the top and bottom edges.
  do
    local frame = newFrame(1)
    local border = assert(Shapes.createBorderBox(frame, { 1, 1, 1, 0.08 }, 1, "BORDER"))
    for _, side in ipairs({ "left", "right" }) do
      local topAnchor = side == "left" and "TOPLEFT" or "TOPRIGHT"
      local bottomAnchor = side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT"
      assert(lastPointY(border[side], topAnchor) == 0, side .. " strip starts at the top edge")
      assert(lastPointY(border[side], bottomAnchor) == 0, side .. " strip ends at the bottom edge")
    end
  end

  -- test_border_edges_snap_to_the_pixel_grid
  -- Unsnapped one-pixel quads at fractional positions can land between
  -- pixel centres and drop out; snapping keeps every edge whole.
  do
    local frame = newFrame(1)
    local border = assert(Shapes.createBorderBox(frame, { 1, 1, 1, 0.08 }, 1, "BORDER"))
    for side, edge in pairs(border) do
      assert(edge.snapToPixelGrid == true, side .. " edge snaps to the pixel grid")
    end
  end

  -- test_every_preset_gets_the_same_hairline
  do
    Theme.SetPreset("wow_native")
    local border = assert(Shapes.createBorderBox(newFrame(1), { 1, 1, 1, 1 }, 1, "BORDER"))
    assert(approx(border.top.height, 768 / 1440), "wow_native: one physical pixel like every preset")
  end

  -- test_refresh_hairlines_follows_scale_change
  -- Thickness is measured at creation; after the window scale changes it
  -- must be re-measured, or a sub-pixel edge snaps to zero and a side vanishes.
  do
    local frame = newFrame(1)
    local border = assert(Shapes.createBorderBox(frame, { 1, 1, 1, 1 }, 1, "BORDER"))
    frame:SetScale(0.8)
    Shapes.refreshHairlines()
    local px = 768 / 1440 / 0.8
    assert(approx(border.top.height, px) and approx(border.bottom.height, px), "top/bottom re-measured after scale change")
    assert(approx(border.left.width, px) and approx(border.right.width, px), "left/right re-measured after scale change")
  end

  -- test_refresh_hairlines_skips_thick_borders
  do
    local frame = newFrame(1)
    local border = assert(Shapes.createBorderBox(frame, { 1, 1, 1, 1 }, 3, "BORDER"))
    frame:SetScale(0.8)
    Shapes.refreshHairlines()
    assert(border.top.height == 3, "explicit thickness is left alone")
  end

  rawset(_G, "GetPhysicalScreenSize", previousPhysical)
  Theme.SetPreset(previousPreset)
  print("PASS: test_pixel_border")
end
