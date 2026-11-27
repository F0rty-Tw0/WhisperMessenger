local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- SmartNavigation marks on single widgets for GamepadNav: each kind once
-- per widget, a jump target once per change. Asked for in combat → one queue, run in call order by settle.
local GamepadMarks = {}

local function weakSet()
  return setmetatable({}, { __mode = "k" })
end

-- deps: inCombat, markIgnored, markFocusable, addJumpOverride,
-- registerNavCallback, directions (SMART_NAV_INPUT_DIRECTION); a missing
-- one = that mark does nothing.
function GamepadMarks.New(deps)
  local inCombat = deps.inCombat
  local queue = {}
  local ignored, focusable = weakSet(), weakSet()
  local targets = {}

  local function apply(fn, widget, a, b)
    if inCombat() then
      table.insert(queue, { fn = fn, widget = widget, a = a, b = b })
      return
    end
    fn(widget, a, b)
  end

  local function mark(memo, fn, widget, a, b)
    if widget == nil or not fn or memo[widget] then
      return
    end
    memo[widget] = true
    apply(fn, widget, a, b)
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

  -- D-pad dirName ("UP"/"DOWN"/"LEFT"/"RIGHT") on widget jumps to
  -- targetFrame; nil clears a target set earlier. SmartNav only ever gets
  -- a frame or nil; it is called only when the target changes.
  function marks.setJumpTarget(widget, dirName, targetFrame)
    if targetFrame ~= nil and type(targetFrame) ~= "table" then
      error("setJumpTarget: target must be a frame or nil")
    end
    local directions = deps.directions
    local unsupported = widget == nil or not deps.addJumpOverride or type(directions) ~= "table" or directions[dirName] == nil
    if unsupported then
      return
    end
    targets[dirName] = targets[dirName] or weakSet()
    local memo = targets[dirName]
    if memo[widget] == targetFrame then
      return
    end
    memo[widget] = targetFrame
    apply(deps.addJumpOverride, widget, directions[dirName], targetFrame)
  end

  -- fn(target) runs after the D-pad left widget in dirName while it had a
  -- jump target there. Once per widget and direction: a later fn is ignored.
  local jumpCallbacks = {}
  function marks.onJump(widget, dirName, fn)
    local directions = deps.directions
    local unsupported = widget == nil or not deps.registerNavCallback or type(directions) ~= "table" or directions[dirName] == nil
    if unsupported then
      return
    end
    jumpCallbacks[dirName] = jumpCallbacks[dirName] or weakSet()
    mark(jumpCallbacks[dirName], deps.registerNavCallback, widget, directions[dirName], function()
      local target = targets[dirName] and targets[dirName][widget]
      if target then
        fn(target)
      end
    end)
  end

  -- Last chain set under each setOrder key.
  local chains = {}

  -- Chains the shown frames of `frames`, in the given order: backDir on
  -- each jumps to the one before, forwardDir to the one after; the ends
  -- get nil. A frame of the key's previous chain that is not in the new
  -- one loses both targets.
  function marks.setOrder(key, frames, backDir, forwardDir)
    local chain, inChain = {}, {}
    for _, frame in ipairs(frames) do
      if frame:IsShown() then
        chain[#chain + 1] = frame
        inChain[frame] = true
      end
    end
    for _, frame in ipairs(chains[key] or {}) do
      if not inChain[frame] then
        marks.setJumpTarget(frame, backDir, nil)
        marks.setJumpTarget(frame, forwardDir, nil)
      end
    end
    for i, frame in ipairs(chain) do
      marks.setJumpTarget(frame, backDir, chain[i - 1])
      marks.setJumpTarget(frame, forwardDir, chain[i + 1])
    end
    chains[key] = chain
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
