local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- SmartNavigation marks on single widgets for GamepadNav: each kind once
-- per widget. Asked for in combat → one queue, run in call order by settle.
local GamepadMarks = {}

local function weakSet()
  return setmetatable({}, { __mode = "k" })
end

-- deps: inCombat, markIgnored, markFocusable, addJumpOverride, directions
-- (SMART_NAV_INPUT_DIRECTION); a missing one = that mark does nothing.
function GamepadMarks.New(deps)
  local inCombat = deps.inCombat
  local queue = {}
  local ignored, focusable = weakSet(), weakSet()
  local overridden = {}

  local function mark(memo, fn, widget, a, b)
    if widget == nil or not fn or memo[widget] then
      return
    end
    memo[widget] = true
    if inCombat() then
      table.insert(queue, { fn = fn, widget = widget, a = a, b = b })
      return
    end
    fn(widget, a, b)
  end

  -- fn runs when the D-pad presses dirName on widget; SmartNav stays on
  -- widget when it returns true, else moves as usual.
  local function jumpOverride(widget, dirName, fn)
    local directions = deps.directions
    if type(directions) ~= "table" or directions[dirName] == nil then
      return
    end
    overridden[dirName] = overridden[dirName] or weakSet()
    mark(overridden[dirName], deps.addJumpOverride, widget, directions[dirName], fn)
  end

  local marks = {}

  -- The D-pad skips widget (and its children unless dontPropagate).
  function marks.ignore(widget, dontPropagate)
    mark(ignored, deps.markIgnored, widget, dontPropagate)
  end

  -- The D-pad can stop on widget even if it is not a button.
  function marks.markFocusable(widget)
    mark(focusable, deps.markFocusable, widget)
  end

  -- D-pad left/right on widget call step(-1) / step(1); focus stays on it,
  -- even when step changed nothing (a slider at its limit).
  function marks.setStepper(widget, step)
    jumpOverride(widget, "LEFT", function()
      step(-1)
      return true
    end)
    jumpOverride(widget, "RIGHT", function()
      step(1)
      return true
    end)
  end

  -- D-pad direction ("UP"/"DOWN") on widget calls onPress(); true = it
  -- handled the press and focus stays, else SmartNav moves as usual.
  function marks.setEdgeOverride(widget, direction, onPress)
    jumpOverride(widget, direction, function()
      if onPress() == true then
        return true
      end
      return nil
    end)
  end

  -- Out of combat only: runs what combat held back, in call order.
  function marks.settle()
    local pending = queue
    queue = {}
    for _, entry in ipairs(pending) do
      entry.fn(entry.widget, entry.a, entry.b)
    end
  end

  return marks
end

ns.MessengerWindowGamepadMarks = GamepadMarks

return GamepadMarks
