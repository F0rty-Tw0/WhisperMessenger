local CompactDock = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.CompactDock")
local FakeUI = require("tests.helpers.fake_ui")

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", "Window", parent)
  return frame, parent
end

return function()
  -- test_left_edge_anchors_top_and_bottom_left_at_full_height
  do
    local frame, parent = build()
    CompactDock.PlaceAtEdge(frame, "left")
    assert(#frame.points == 2, "two points, got " .. #frame.points)
    local top, bottom = frame.points[1], frame.points[2]
    assert(top[1] == "TOPLEFT" and top[2] == parent and top[3] == "TOPLEFT" and top[4] == 0 and top[5] == 0, "top point")
    assert(bottom[1] == "BOTTOMLEFT" and bottom[2] == parent and bottom[3] == "BOTTOMLEFT" and bottom[4] == 0 and bottom[5] == 0, "bottom point")
  end

  -- test_right_edge_anchors_top_and_bottom_right
  do
    local frame, parent = build()
    CompactDock.PlaceAtEdge(frame, "right")
    assert(frame.points[1][1] == "TOPRIGHT" and frame.points[1][3] == "TOPRIGHT" and frame.points[1][2] == parent, "top point")
    assert(frame.points[2][1] == "BOTTOMRIGHT" and frame.points[2][3] == "BOTTOMRIGHT" and frame.points[2][5] == 0, "bottom point")
  end

  -- test_placing_again_replaces_the_old_points
  do
    local frame = build()
    CompactDock.PlaceAtEdge(frame, "left")
    CompactDock.PlaceAtEdge(frame, "right")
    assert(#frame.points == 2 and frame.points[1][1] == "TOPRIGHT", "old points cleared")
  end
end
