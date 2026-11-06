local PhoneDock = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDock")
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
    PhoneDock.Place(frame, slot, icon)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    assert(point == "TOPLEFT" and relativeTo == parent and relativePoint == "BOTTOMLEFT", "screen-anchored")
    -- The spot sits 25 right of and 25 below the corner.
    assert(x == 475 and y == 625, "got " .. tostring(x) .. "," .. tostring(y))
  end

  -- test_spot_with_no_position_yet_still_places_the_window
  do
    local frame, slot, icon = build()
    centerAt(slot, nil, nil)
    PhoneDock.Place(frame, slot, icon)
    local _, _, _, x, y = frame:GetPoint()
    assert(x == 500 and y == 600, "corner on the button; the glide finds the spot once it exists")
  end

  -- test_no_button_leaves_the_window_where_it_is
  do
    local frame, slot, _, parent = build()
    frame:SetPoint("CENTER", parent, "CENTER", 5, 6)
    PhoneDock.Place(frame, slot, nil)
    assert(select(4, frame:GetPoint()) == 5, "position untouched")
  end

  -- test_ride_target_is_the_spot_at_the_spots_size
  do
    local _, slot, icon = build()
    local target = PhoneDock.RideTarget(slot, icon)
    assert(target.region == slot, "rides the spot")
    assert(target.relativePoint == "CENTER" and target.x == 0 and target.y == 0, "centred on it")
    assert(target.scale == 2, "grows to the spot's size, got " .. tostring(target.scale))
    assert(target.level == Theme.LAYOUT.PHONE_RIDE_FRAME_LEVEL, "above the raised window")
  end

  -- test_unsized_spot_keeps_the_button_size
  do
    local _, slot, icon = build()
    slot:SetSize(0, 0)
    assert(PhoneDock.RideTarget(slot, icon).scale == 1, "no size to grow to")
  end

  -- test_capture_position_is_absolute
  do
    local frame = build()
    local state = PhoneDock.CapturePosition(frame)
    assert(state.anchorPoint == "TOPLEFT" and state.relativePoint == "BOTTOMLEFT", "screen-relative anchor")
    assert(state.x == 100 and state.y == 900, "saved from the frame's real edges")
  end
end
