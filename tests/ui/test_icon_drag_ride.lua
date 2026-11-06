local IconDrag = require("WhisperMessenger.UI.ToggleIcon.IconDrag")
local FakeUI = require("tests.helpers.fake_ui")

local function build(locked)
  local frame = FakeUI.NewFactory().CreateFrame("Button", "Fab", nil)
  frame:SetMovable(true)
  local case = { moved = 0, saved = 0, frame = frame }
  rawset(frame, "StartMoving", function()
    case.moved = case.moved + 1
  end)
  rawset(frame, "StopMovingOrSizing", function() end)
  case.drag = IconDrag.Attach(frame, function()
    return locked == true
  end, {
    onPositionChanged = function()
      case.saved = case.saved + 1
    end,
  })
  return case
end

return function()
  -- test_dragging_the_riding_icon_moves_the_window
  do
    local case = build()
    local started, stopped = 0, 0
    case.drag.setRideHandlers({
      beginDrag = function()
        started = started + 1
      end,
      endDrag = function()
        stopped = stopped + 1
      end,
    })
    case.frame.scripts.OnDragStart(case.frame)
    case.frame.scripts.OnDragStop(case.frame)
    assert(started == 1 and stopped == 1, "the window goes where the icon is dragged")
    assert(case.moved == 0 and case.saved == 0, "the icon itself stays pinned")
  end

  -- test_locked_icon_holds_the_window_too
  do
    local case = build(true)
    local started = 0
    case.drag.setRideHandlers({
      beginDrag = function()
        started = started + 1
      end,
      endDrag = function() end,
    })
    case.frame.scripts.OnDragStart(case.frame)
    assert(started == 0, "locked means locked")
  end

  -- test_after_riding_the_icon_drags_itself_again
  do
    local case = build()
    case.drag.setRideHandlers({ beginDrag = function() end, endDrag = function() end })
    case.drag.setRideHandlers(nil)
    case.frame.scripts.OnDragStart(case.frame)
    assert(case.moved == 1, "back to normal")
  end
end
