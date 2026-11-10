local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Moves an open window to a saved state handed in from outside (a shared
-- position from another character), and lets the docked button follow.
local SavedStateApply = {}

-- The compact window's saved state carries compactLayout; a shared one may
-- not, and without it the size is clamped to the classic window's minimum.
local function compactCopy(state)
  local copy = {}
  for key, value in pairs(state) do
    copy[key] = value
  end
  copy.compactLayout = true
  return copy
end

-- options: compactLayout, compactMode (CompactWiring hooks), dock (DockWiring
-- hooks), scriptResult (LifecycleWiring). Hook fields are read at call time.
-- Returns applySavedState(state) for the window table and applyPending(state)
-- for CompactWiring.Attach.
function SavedStateApply.Create(options)
  local compactMode = options.compactMode
  local dock = options.dock
  local scriptResult = options.scriptResult

  local function applyPending(state)
    scriptResult.applyState(state)
    dock.onWindowMoved()
  end

  -- An empty state is the compact reset marker: compact size, centred. While
  -- settings widen the compact window the state waits until they close.
  local function applySavedState(state)
    if not options.compactLayout then
      applyPending(state)
      return
    end
    if state.anchorPoint == nil then
      compactMode.resetWindow()
      dock.onWindowMoved()
      return
    end
    if compactMode.isWide() then
      compactMode.applyWhenNarrow(compactCopy(state))
      return
    end
    applyPending(compactCopy(state))
  end

  return applySavedState, applyPending
end

ns.MessengerWindowSavedStateApply = SavedStateApply

return SavedStateApply
