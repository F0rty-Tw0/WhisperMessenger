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

-- deps: inCombat, markIgnored, markFocusable (a missing one = that mark
-- does nothing).
function GamepadMarks.New(deps)
  local inCombat = deps.inCombat
  local queue = {}
  local ignored, focusable = weakSet(), weakSet()

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

  local marks = {}

  -- The D-pad skips widget (and its children unless dontPropagate).
  function marks.ignore(widget, dontPropagate)
    mark(ignored, deps.markIgnored, widget, dontPropagate)
  end

  -- The D-pad can stop on widget even if it is not a button.
  function marks.markFocusable(widget)
    mark(focusable, deps.markFocusable, widget)
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
