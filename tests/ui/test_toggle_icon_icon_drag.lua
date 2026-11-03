local FakeUI = require("tests.helpers.fake_ui")
local IconDrag = require("WhisperMessenger.UI.ToggleIcon.IconDrag")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local function build(locked, options)
    local frame = factory.CreateFrame("Button", nil, parent)
    frame:SetMovable(true)
    frame:SetPoint("CENTER", parent, "CENTER", 12, -7)
    IconDrag.Attach(frame, function()
      return locked
    end, options or {})
    return frame
  end

  -- test_drag_start_ignored_while_locked

  do
    local frame = build(true)
    frame:GetScript("OnDragStart")(frame)
    assert(frame.moving ~= true, "test_drag_start_ignored_while_locked: a locked icon must not start moving")
  end

  -- test_drag_start_moves_unlocked_icon

  do
    local frame = build(false)
    frame:GetScript("OnDragStart")(frame)
    assert(frame.moving == true, "test_drag_start_moves_unlocked_icon: an unlocked icon should start moving")
  end

  -- test_drag_stop_reports_new_position

  do
    local reported
    local frame = build(false, {
      onPositionChanged = function(nextState)
        reported = nextState
      end,
    })
    frame:GetScript("OnDragStart")(frame)
    frame:GetScript("OnDragStop")(frame)

    assert(frame.moving == false, "test_drag_stop_reports_new_position: drop should stop moving")
    assert(reported ~= nil, "test_drag_stop_reports_new_position: drop should report the position")
    assert(
      reported.x == 12 and reported.y == -7,
      "test_drag_stop_reports_new_position: got x=" .. tostring(reported.x) .. " y=" .. tostring(reported.y)
    )
  end
end
