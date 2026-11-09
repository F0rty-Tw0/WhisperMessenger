local KeySettle = require("WhisperMessenger.Core.KeySettle")

local LOW_FPS_FRAME_SECONDS = 0.1

return function()
  local savedCTimer = _G.C_Timer

  local function makeClock()
    local clock = { now = 0, pending = {} }

    rawset(_G, "C_Timer", {
      After = function(seconds, fn)
        table.insert(clock.pending, { due = clock.now + seconds, fn = fn })
      end,
    })

    -- Callbacks scheduled while a frame's timers run wait for a later frame.
    function clock.frame()
      clock.now = clock.now + LOW_FPS_FRAME_SECONDS
      local due, waiting = {}, {}
      for _, entry in ipairs(clock.pending) do
        table.insert(entry.due <= clock.now and due or waiting, entry)
      end
      clock.pending = waiting
      for _, entry in ipairs(due) do
        entry.fn()
      end
    end

    return clock
  end

  -- test_after_waits_one_frame_plus_settle
  do
    local clock = makeClock()
    local runs = 0
    KeySettle.After(function()
      runs = runs + 1
    end)
    clock.frame()
    assert(runs == 0, "callback must wait past the first frame, ran " .. runs)
    clock.frame()
    assert(runs == 1, "callback must run once the settle delay passed, ran " .. runs)
    for _ = 1, 3 do
      clock.frame()
    end
    assert(runs == 1, "callback must run exactly once, ran " .. runs)
  end

  -- test_after_runs_at_once_without_timer
  do
    rawset(_G, "C_Timer", nil)
    local runs = 0
    KeySettle.After(function()
      runs = runs + 1
    end)
    assert(runs == 1, "callback must run at once without C_Timer, ran " .. runs)
  end

  rawset(_G, "C_Timer", savedCTimer)
end
