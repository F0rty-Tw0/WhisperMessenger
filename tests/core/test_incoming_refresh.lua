-- Incoming chat lines are coalesced: at most one window refresh per 0.2 s,
-- carrying every conversation key that changed in that window.

local IncomingRefresh = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.IncomingRefresh")
local PerfCounters = require("WhisperMessenger.Util.PerfCounters")

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

-- Whispers coalesce only within one frame: a zero-delay timer, no
-- visibility gate (a hidden window still updates its icon badges).
local function whisperHarness(guard)
  local h = { timers = {}, delays = {}, calls = {} }
  h.schedule = IncomingRefresh.NextFrame({
    guard = guard,
    cTimer = {
      After = function(delay, fn)
        h.delays[#h.delays + 1] = delay
        h.timers[#h.timers + 1] = fn
      end,
    },
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

  -- test_each_flush_counts_one_refresh
  do
    PerfCounters.Reset()
    local h = harness()
    h.refresh.schedule("a")
    h.refresh.schedule("b")
    h.timers[1]()
    h.refresh.schedule(nil)
    h.timers[2]()
    assert(PerfCounters.Get("refreshes") == 2, "each flush counts one refresh, got " .. PerfCounters.Get("refreshes"))
  end

  -- test_two_whispers_in_one_frame_refresh_once
  do
    local h = whisperHarness()
    h.schedule("a")
    h.schedule("b")
    assert(#h.calls == 0, "whispers in one frame must not refresh synchronously")
    assert(#h.timers == 1 and h.delays[1] == 0, "one zero-delay timer for the frame, got " .. #h.timers)
    h.timers[1]()
    assert(#h.calls == 1, "two whispers in one frame refresh once, got " .. #h.calls)
  end

  -- test_coalesced_whisper_refresh_focuses_the_dirty_selected_key
  do
    local h = whisperHarness()
    h.schedule("a")
    h.schedule("sel")
    h.schedule("b")
    h.timers[1]()
    assert(h.calls[1].key == "sel", "selected chat among the whispers -> focus it, got " .. tostring(h.calls[1].key))
  end

  -- test_coalesced_whisper_refresh_rebuilds_every_contact
  do
    local h = whisperHarness()
    h.schedule("a")
    h.schedule("b")
    h.timers[1]()
    assert(h.calls[1].dirty == nil, "a whisper refresh stays a full contact rebuild")
    assert(h.calls[1].key == "a" or h.calls[1].key == "b", "focus is one of the whisper keys, got " .. tostring(h.calls[1].key))
  end

  -- test_whisper_after_flush_arms_next_frame
  do
    local h = whisperHarness()
    h.schedule("a")
    h.timers[1]()
    h.schedule("b")
    assert(#h.timers == 2, "a whisper after the flush arms a new frame")
    h.timers[2]()
    assert(#h.calls == 2 and h.calls[2].key == "b", "the next frame refreshes for its own whisper")
  end

  -- test_whisper_refresh_is_immediate_without_timer_api
  do
    local calls = {}
    local schedule = IncomingRefresh.NextFrame({
      cTimer = nil,
      getSelectedKey = function()
        return "sel"
      end,
      refreshWindow = function(key, dirty)
        calls[#calls + 1] = { key = key, dirty = dirty }
      end,
    })
    schedule("a")
    assert(#calls == 1 and calls[1].key == "a", "no timer API -> refresh at once")
  end

  -- test_whisper_flush_counts_one_refresh
  do
    PerfCounters.Reset()
    local h = whisperHarness()
    h.schedule("a")
    h.schedule("b")
    h.timers[1]()
    assert(PerfCounters.Get("refreshes") == 1, "one whisper flush counts one refresh, got " .. PerfCounters.Get("refreshes"))
  end

  -- test_whisper_refresh_without_timer_api_counts_one_refresh
  do
    PerfCounters.Reset()
    local schedule = IncomingRefresh.NextFrame({
      cTimer = nil,
      getSelectedKey = function()
        return "sel"
      end,
      refreshWindow = function() end,
    })
    schedule("a")
    assert(PerfCounters.Get("refreshes") == 1, "an immediate whisper refresh counts too, got " .. PerfCounters.Get("refreshes"))
  end

  -- test_whisper_flush_runs_under_the_guard_with_every_line
  do
    local guarded = {}
    local h = whisperHarness(function(lines, run)
      guarded[#guarded + 1] = lines
      run()
    end)
    local lineA, lineB = { text = "one" }, { text = "two" }
    h.schedule("a", lineA)
    h.schedule("b", lineB)
    h.timers[1]()
    assert(#guarded == 1, "one guarded run per flush, got " .. #guarded)
    assert(guarded[1][1] == lineA and guarded[1][2] == lineB, "the guard gets every line of the frame")
    assert(#h.calls == 1, "the guarded run refreshes the window once, got " .. #h.calls)
  end

  -- test_whisper_flush_guard_gets_only_its_own_frame_lines
  do
    local guarded = {}
    local h = whisperHarness(function(lines, run)
      guarded[#guarded + 1] = lines
      run()
    end)
    local lineA, lineB = { text = "one" }, { text = "two" }
    h.schedule("a", lineA)
    h.timers[1]()
    h.schedule("b", lineB)
    h.timers[2]()
    assert(#guarded[2] == 1 and guarded[2][1] == lineB, "a flushed line must not carry into the next frame")
  end
end
