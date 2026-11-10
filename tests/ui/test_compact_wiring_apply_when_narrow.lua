local CompactWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.CompactWiring")
local DockWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.DockWiring")
local WindowSizing = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowSizing")
local Theme = require("WhisperMessenger.UI.Theme")
local CompactWindow = require("tests.helpers.compact_window")

-- A shared spot from another character: no compactLayout flag, a compact size.
local function sharedCompactState()
  return { anchorPoint = "TOPLEFT", relativePoint = "TOPLEFT", x = 40, y = -60, width = 380, height = 660, contactsWidth = 200 }
end

-- A real window whose dock hooks count every onWindowMoved after Attach filled them.
local function buildCountingDock(extra)
  local attach, moved = DockWiring.Attach, { count = 0 }
  DockWiring.Attach = function(window, parts)
    local result = attach(window, parts)
    local hooks = parts.hooks
    local onWindowMoved = hooks.onWindowMoved
    hooks.onWindowMoved = function()
      moved.count = moved.count + 1
      return onWindowMoved()
    end
    return result
  end
  local ok, case = pcall(CompactWindow.Build, extra)
  DockWiring.Attach = attach
  assert(ok, case)
  case.window.frame:Show()
  return case, moved
end

-- A real compact window whose Attach gets a recording applyPending. The spy
-- notes the window width at call time, to prove the narrow size came back first.
local function buildWithSpy()
  local attach, seen = CompactWiring.Attach, { pending = {}, widths = {} }
  CompactWiring.Attach = function(hooks, options)
    seen.hooks = hooks
    options.applyPending = function(state)
      seen.pending[#seen.pending + 1] = state
      seen.widths[#seen.widths + 1] = options.frame:GetWidth()
    end
    return attach(hooks, options)
  end
  local ok, case = pcall(CompactWindow.Build)
  CompactWiring.Attach = attach
  assert(ok, case)
  case.window.frame:Show()
  return case, seen
end

return function()
  -- test_saved_state_applied_while_wide_lands_when_settings_close
  do
    local _case, seen = buildWithSpy()
    local state = { anchorPoint = "TOPLEFT", x = 10, y = -10 }
    seen.hooks.onCoverChanged(true)
    seen.hooks.applyWhenNarrow(state)
    assert(#seen.pending == 0, "nothing applies while the window is wide")
    seen.hooks.onCoverChanged(false)
    assert(#seen.pending == 1, "the pending state applies when settings close")
    assert(seen.pending[1] == state, "the stored state is the one applied")
    -- Settings open and close again: the state already applied must not come back.
    seen.hooks.onCoverChanged(true)
    seen.hooks.onCoverChanged(false)
    assert(#seen.pending == 1, "a pending state applies once; applies: " .. tostring(#seen.pending))
  end

  -- test_pending_state_applies_after_the_narrow_size_is_back
  do
    local case, seen = buildWithSpy()
    local narrow = case.window.frame:GetWidth()
    seen.hooks.onCoverChanged(true)
    assert(case.window.frame:GetWidth() ~= narrow, "the cover widened the window")
    seen.hooks.applyWhenNarrow({ anchorPoint = "CENTER" })
    seen.hooks.onCoverChanged(false)
    assert(seen.widths[1] == narrow, "the narrow size is restored before the apply")
  end

  -- test_a_newer_pending_state_replaces_the_older_one
  do
    local _case, seen = buildWithSpy()
    local older, newer = { anchorPoint = "LEFT" }, { anchorPoint = "RIGHT" }
    seen.hooks.onCoverChanged(true)
    seen.hooks.applyWhenNarrow(older)
    seen.hooks.applyWhenNarrow(newer)
    seen.hooks.onCoverChanged(false)
    assert(#seen.pending == 1 and seen.pending[1] == newer, "only the newest state applies")
  end

  -- test_reset_under_settings_drops_the_pending_state
  do
    local _case, seen = buildWithSpy()
    seen.hooks.onCoverChanged(true)
    seen.hooks.applyWhenNarrow({ anchorPoint = "LEFT" })
    seen.hooks.resetWindow()
    seen.hooks.onCoverChanged(false)
    assert(#seen.pending == 0, "the newer reset wins over the older pending state")
  end

  -- test_idle_hooks_ignore_apply_when_narrow
  do
    local hooks = CompactWiring.Hooks()
    hooks.applyWhenNarrow({ anchorPoint = "CENTER" })
  end

  -- test_default_marker_on_compact_window_uses_compact_size_and_centers
  do
    local case = buildCountingDock()
    local frame = case.window.frame
    case.window.applySavedState(sharedCompactState())
    case.window.applySavedState({})
    local defaults = WindowSizing.InitialState(frame:GetParent(), {}, 1, true)
    assert(frame:GetWidth() == defaults.width, "compact default width, got " .. tostring(frame:GetWidth()))
    assert(frame:GetHeight() == defaults.height, "compact default height, got " .. tostring(frame:GetHeight()))
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    local L = Theme.LAYOUT
    assert(point == "TOPLEFT" and relativeTo == frame:GetParent() and relativePoint == "CENTER", "placed from the screen centre")
    assert(x == -L.COMPACT_WINDOW_WIDTH / 2 and y == L.COMPACT_WINDOW_HEIGHT / 2, "centred, got " .. tostring(x) .. "," .. tostring(y))
  end

  -- test_shared_compact_state_applied_live_keeps_the_compact_size
  do
    local case = buildCountingDock()
    case.window.applySavedState(sharedCompactState())
    local frame = case.window.frame
    assert(frame:GetWidth() == 380, "not snapped to the classic minimum, got " .. tostring(frame:GetWidth()))
    local point, _, relativePoint, x, y = frame:GetPoint()
    assert(point == "TOPLEFT" and relativePoint == "TOPLEFT" and x == 40 and y == -60, "moved to the shared spot")
  end

  -- test_shared_compact_state_applied_under_settings_lands_at_compact_size_when_they_close
  do
    local case = buildCountingDock()
    local frame = case.window.frame
    case.window.setOptionsVisible(true)
    local wide = frame:GetWidth()
    case.window.applySavedState(sharedCompactState())
    assert(frame:GetWidth() == wide, "the wide settings window does not move or shrink")
    case.window.setOptionsVisible(false)
    assert(frame:GetWidth() == 380, "the shared compact size lands once settings close, got " .. tostring(frame:GetWidth()))
    local _, _, _, x, y = frame:GetPoint()
    assert(x == 40 and y == -60, "and the shared spot")
  end

  -- test_docked_widget_follows_a_live_shared_apply
  do
    local case, moved = buildCountingDock()
    case.window.applySavedState(sharedCompactState())
    assert(moved.count == 1, "direct apply, got " .. moved.count)
    case.window.applySavedState({})
    assert(moved.count == 2, "default marker, got " .. moved.count)
    case.window.setOptionsVisible(true)
    case.window.applySavedState(sharedCompactState())
    assert(moved.count == 2, "nothing moves while settings are wide")
    case.window.setOptionsVisible(false)
    assert(moved.count == 3, "the pending apply, got " .. moved.count)
  end

  -- test_classic_window_applies_the_shared_state_as_is
  do
    local case, moved = buildCountingDock({ compactLayout = false })
    local frame = case.window.frame
    case.window.applySavedState({ anchorPoint = "TOPLEFT", relativePoint = "TOPLEFT", x = 30, y = -20, width = 700, height = 500 })
    assert(frame:GetWidth() == 700 and frame:GetHeight() == 500, "the shared size")
    local _, _, _, x, y = frame:GetPoint()
    assert(x == 30 and y == -20, "the shared spot")
    assert(moved.count == 1, "the docked widget follows")
  end
end
