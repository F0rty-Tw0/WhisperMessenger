local CompactWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.CompactWiring")
local CompactWindow = require("tests.helpers.compact_window")

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
    seen.hooks.onCoverChanged(false)
    assert(#seen.pending == 1, "a pending state applies once")
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

  -- test_idle_hooks_ignore_apply_when_narrow
  do
    local hooks = CompactWiring.Hooks()
    hooks.applyWhenNarrow({ anchorPoint = "CENTER" })
  end
end
