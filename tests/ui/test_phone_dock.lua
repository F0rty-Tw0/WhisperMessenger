local PhoneDock = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDock")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local OVERLAP = Theme.LAYOUT.PHONE_CORNER_OVERLAP

local function centerAt(frame, x, y)
  rawset(frame, "GetCenter", function()
    return x, y
  end)
end

local function build(withPortrait)
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
  if withPortrait then
    local container = factory.CreateFrame("Frame", nil, frame)
    container:SetSize(60, 60)
    local portrait = factory.CreateFrame("Frame", nil, container)
    portrait:SetSize(84, 84)
    centerAt(portrait, 125, 875)
    container.portrait = portrait
    frame.PortraitContainer = container
  end
  return frame, icon, parent
end

return function()
  -- test_portrait_lands_on_the_button
  do
    local frame, icon, parent = build(true)
    PhoneDock.Place(frame, icon)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    assert(point == "TOPLEFT" and relativeTo == parent and relativePoint == "BOTTOMLEFT", "screen-anchored")
    -- The portrait sits 25 right of and 25 below the corner.
    assert(x == 475 and y == 625, "got " .. tostring(x) .. "," .. tostring(y))
  end

  -- test_window_without_a_portrait_hangs_from_the_button_corner
  do
    local frame, icon = build(false)
    PhoneDock.Place(frame, icon)
    local _, _, _, x, y = frame:GetPoint()
    assert(x == 500 + 21 - OVERLAP, "corner right of the button, got " .. tostring(x))
    assert(y == 600 - 21 + OVERLAP, "corner below the button, got " .. tostring(y))
  end

  -- test_no_button_leaves_the_window_where_it_is
  do
    local frame, _, parent = build(true)
    frame:SetPoint("CENTER", parent, "CENTER", 5, 6)
    PhoneDock.Place(frame, nil)
    assert(select(4, frame:GetPoint()) == 5, "position untouched")
  end

  -- test_ride_target_matches_the_portrait
  do
    local frame, icon = build(true)
    local target = PhoneDock.RideTarget(frame, icon)
    assert(target.region == frame.PortraitContainer.portrait, "rides the portrait")
    assert(target.relativePoint == "CENTER" and target.x == 0 and target.y == 0, "centred on it")
    assert(target.scale == 2, "grows to the portrait's size, got " .. tostring(target.scale))
    assert(target.level == Theme.LAYOUT.PHONE_RIDE_FRAME_LEVEL, "above the raised window")
  end

  -- test_ride_target_without_a_portrait_keeps_the_button_size
  do
    local frame, icon = build(false)
    local target = PhoneDock.RideTarget(frame, icon)
    assert(target.region == frame and target.relativePoint == "TOPLEFT", "rides the window corner")
    assert(target.x == -(21 - OVERLAP) and target.y == 21 - OVERLAP, "hangs off the corner")
    assert(target.scale == 1, "same size")
  end

  -- test_capture_position_is_absolute
  do
    local frame = build(false)
    local state = PhoneDock.CapturePosition(frame)
    assert(state.anchorPoint == "TOPLEFT" and state.relativePoint == "BOTTOMLEFT", "screen-relative anchor")
    assert(state.x == 100 and state.y == 900, "saved from the frame's real edges")
  end
end
