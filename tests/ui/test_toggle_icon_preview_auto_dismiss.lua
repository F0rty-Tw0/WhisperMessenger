local PreviewAutoDismiss = require("WhisperMessenger.UI.ToggleIcon.PreviewAutoDismiss")

-- Runs fn(timers) with a C_Timer stub that records every timer it makes.
local function withTimers(fn)
  local saved = _G.C_Timer
  local timers = {}
  rawset(_G, "C_Timer", {
    NewTimer = function(seconds, callback)
      local timer = { seconds = seconds, callback = callback, cancelled = false }
      timer.Cancel = function(self)
        self.cancelled = true
      end
      timers[#timers + 1] = timer
      return timer
    end,
  })
  local ok, err = pcall(fn, timers)
  rawset(_G, "C_Timer", saved)
  assert(ok, err)
end

local function build(opts)
  local state = { expired = 0 }
  state.autoDismiss = PreviewAutoDismiss.New({
    getSeconds = function()
      return opts.seconds
    end,
    isShown = function()
      return opts.shown ~= false
    end,
    onExpire = function()
      state.expired = state.expired + 1
    end,
  })
  return state
end

return function()
  local function test_schedule_expires_after_the_chosen_delay()
    withTimers(function(timers)
      local s = build({ seconds = 5 })
      s.autoDismiss.schedule()
      assert(#timers == 1 and timers[1].seconds == 5, "one timer for the chosen delay")
      timers[1].callback()
      assert(s.expired == 1, "the timer expires the preview")
    end)
  end

  local function test_zero_seconds_schedules_nothing()
    withTimers(function(timers)
      build({ seconds = 0 }).autoDismiss.schedule()
      assert(#timers == 0, "zero means never auto-dismiss")
    end)
  end

  local function test_reschedule_cancels_the_old_timer()
    withTimers(function(timers)
      local s = build({ seconds = 5 })
      s.autoDismiss.schedule()
      s.autoDismiss.schedule()
      assert(timers[1].cancelled == true, "the old timer is cancelled")
      timers[1].callback()
      assert(s.expired == 0, "a stale timer never expires the preview")
    end)
  end

  local function test_cancel_stops_the_pending_timer()
    withTimers(function(timers)
      local s = build({ seconds = 5 })
      s.autoDismiss.schedule()
      s.autoDismiss.cancel()
      timers[1].callback()
      assert(timers[1].cancelled == true and s.expired == 0, "cancel stops the timer")
    end)
  end

  local function test_hidden_preview_does_not_expire()
    withTimers(function(timers)
      local s = build({ seconds = 5, shown = false })
      s.autoDismiss.schedule()
      timers[1].callback()
      assert(s.expired == 0, "an already hidden preview is left alone")
    end)
  end

  test_schedule_expires_after_the_chosen_delay()
  test_zero_seconds_schedules_nothing()
  test_reschedule_cancels_the_old_timer()
  test_cancel_stops_the_pending_timer()
  test_hidden_preview_does_not_expire()
end
