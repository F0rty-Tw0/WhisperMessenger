local CompactDock = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.CompactDock")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local function centerAt(frame, x, y)
  rawset(frame, "GetCenter", function()
    return x, y
  end)
end

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(1920, 1080)
  local frame = factory.CreateFrame("Frame", "Window", parent)
  frame:SetSize(360, 640)
  local icon = factory.CreateFrame("Button", "Fab", parent)
  icon:SetSize(42, 42)
  centerAt(icon, 500, 600)
  rawset(frame, "GetLeft", function()
    return 100
  end)
  rawset(frame, "GetTop", function()
    return 900
  end)
  local slot = factory.CreateFrame("Frame", nil, frame)
  slot:SetSize(84, 84)
  centerAt(slot, 125, 875)
  return frame, slot, icon, parent
end

return function()
  -- test_the_icon_spot_lands_on_the_button
  do
    local frame, slot, icon, parent = build()
    CompactDock.Place(frame, slot, icon)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    assert(point == "TOPLEFT" and relativeTo == parent and relativePoint == "BOTTOMLEFT", "screen-anchored")
    -- The spot sits 25 right of and 25 below the corner.
    assert(x == 475 and y == 625, "got " .. tostring(x) .. "," .. tostring(y))
  end

  -- test_placing_converts_the_buttons_screen_position_to_the_windows_scale
  do
    local frame, slot, icon, parent = build()
    rawset(icon, "GetEffectiveScale", function()
      return 2
    end)
    rawset(frame, "GetEffectiveScale", function()
      return 4
    end)
    CompactDock.Place(frame, slot, icon)
    local _, relativeTo, _, x, y = frame:GetPoint()
    assert(relativeTo == parent, "screen-anchored")
    -- The button's 500,600 is 250,300 in the window's coordinates; the spot sits 25 right of and 25 below the corner.
    assert(x == 225 and y == 325, "got " .. tostring(x) .. "," .. tostring(y))
  end

  -- test_spot_with_no_position_yet_still_places_the_window
  do
    local frame, slot, icon = build()
    centerAt(slot, nil, nil)
    CompactDock.Place(frame, slot, icon)
    local _, _, _, x, y = frame:GetPoint()
    assert(x == 500 and y == 600, "corner on the button; the glide finds the spot once it exists")
  end

  -- test_no_button_leaves_the_window_where_it_is
  do
    local frame, slot, _, parent = build()
    frame:SetPoint("CENTER", parent, "CENTER", 5, 6)
    CompactDock.Place(frame, slot, nil)
    assert(select(4, frame:GetPoint()) == 5, "position untouched")
  end

  -- test_ride_target_is_the_spot_at_the_spots_size
  do
    local _, slot, icon = build()
    local target = CompactDock.RideTarget(slot, icon)
    assert(target.region == slot, "rides the spot")
    assert(target.relativePoint == "CENTER" and target.x == 0 and target.y == 0, "centred on it")
    assert(target.scale == 2, "grows to the spot's size, got " .. tostring(target.scale))
    assert(target.level == Theme.LAYOUT.COMPACT_RIDE_FRAME_LEVEL, "above the raised window")
  end

  -- test_docking_again_keeps_the_spots_size
  do
    local frame, slot, icon = build()
    frame:SetScale(1.25)
    local first = CompactDock.RideTarget(slot, icon)
    assert(first.scale == 2.5, "grows to the scaled spot, got " .. tostring(first.scale))
    icon:SetScale(first.scale)
    local second = CompactDock.RideTarget(slot, icon)
    assert(second.scale == 2.5, "the button's own ride scale does not count twice, got " .. tostring(second.scale))
  end

  -- test_unsized_spot_keeps_the_button_size
  do
    local _, slot, icon = build()
    slot:SetSize(0, 0)
    assert(CompactDock.RideTarget(slot, icon).scale == 1, "no size to grow to")
  end

  -- test_the_clamp_reaches_over_a_spot_past_the_corner
  do
    local frame, slot = build()
    frame:SetClampRectInsets(0, 3, 0, -30)
    rawset(slot, "GetLeft", function()
      return 93
    end)
    rawset(slot, "GetTop", function()
      return 917
    end)
    assert(CompactDock.ClampToSpot(frame, slot) == true, "measured")
    local left, right, top, bottom = frame:GetClampRectInsets()
    assert(left == -7 and top == 17, "got " .. tostring(left) .. "," .. tostring(top))
    assert(right == 3 and bottom == -30, "the other edges are left alone")
  end

  -- test_a_spot_inside_the_window_needs_no_clamp
  do
    local frame, slot = build()
    rawset(slot, "GetLeft", function()
      return 110
    end)
    rawset(slot, "GetTop", function()
      return 880
    end)
    CompactDock.ClampToSpot(frame, slot)
    local left, _, top = frame:GetClampRectInsets()
    assert(left == 0 and top == 0, "nothing sticks out")
  end

  -- test_a_spot_with_no_position_yet_reports_it
  do
    local frame, slot = build()
    assert(CompactDock.ClampToSpot(frame, slot) == false, "worth another try")
    assert(frame.clampRectInsets == nil, "untouched")
  end

  -- test_capture_position_is_absolute
  do
    local frame = build()
    local state = CompactDock.CapturePosition(frame)
    assert(state.anchorPoint == "TOPLEFT" and state.relativePoint == "BOTTOMLEFT", "screen-relative anchor")
    assert(state.x == 100 and state.y == 900, "saved from the frame's real edges")
  end
end
