-- Incoming chat lines are coalesced: at most one window refresh per 0.2 s,
-- carrying every conversation key that changed in that window.

local IncomingRefresh = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IncomingRefresh")

local function harness(visible)
  local h = { timers = {}, delays = {}, calls = {}, visible = visible ~= false }
  h.refresh = IncomingRefresh.Create({
    cTimer = {
      After = function(delay, fn)
        h.delays[#h.delays + 1] = delay
        h.timers[#h.timers + 1] = fn
      end,
    },
    isWindowVisible = function()
      return h.visible
    end,
    getSelectedKey = function()
      return "sel"
    end,
    refreshWindow = function(key, dirty)
      h.calls[#h.calls + 1] = { key = key, dirty = dirty }
    end,
  })
  return h
end

return function()
  -- test_lines_in_one_window_coalesce_into_one_refresh
  do
    local h = harness()
    h.refresh.schedule("a")
    h.refresh.schedule("b")
    h.refresh.schedule("a")
    assert(#h.timers == 1, "three lines arm one timer, got " .. #h.timers)
    assert(h.delays[1] == 0.2, "default coalesce window is 0.2s, got " .. tostring(h.delays[1]))
    h.timers[1]()
    assert(#h.calls == 1, "one refresh per window, got " .. #h.calls)
    assert(h.calls[1].dirty.a and h.calls[1].dirty.b, "the refresh carries both keys")
    assert(h.calls[1].key ~= "sel", "selected not dirty -> contacts-only key")
  end

  -- test_dirty_selected_conversation_is_the_focus_key
  do
    local h = harness()
    h.refresh.schedule("a")
    h.refresh.schedule("sel")
    h.timers[1]()
    assert(h.calls[1].key == "sel", "selected dirty -> focus selected, got " .. tostring(h.calls[1].key))
  end

  -- test_next_window_carries_only_its_own_keys
  do
    local h = harness()
    h.refresh.schedule("a")
    h.timers[1]()
    h.refresh.schedule("b")
    assert(#h.timers == 2, "a line after a flush arms a new timer")
    h.timers[2]()
    assert(h.calls[2].dirty.b and not h.calls[2].dirty.a, "a flushed key must not carry into the next window")
  end

  -- test_hidden_window_records_nothing
  do
    local h = harness(false)
    h.refresh.schedule("a")
    assert(#h.timers == 0, "hidden window arms no timer")
    h.visible = true
    h.refresh.schedule("b")
    h.timers[1]()
    assert(not h.calls[1].dirty.a, "a line while hidden must not be recorded")
  end

  -- test_line_without_key_forces_full_refresh
  do
    local h = harness()
    h.refresh.schedule("a")
    h.refresh.schedule(nil)
    h.timers[1]()
    assert(#h.calls == 1 and h.calls[1].dirty == nil, "an unkeyed line must request a full rebuild")
  end
end
