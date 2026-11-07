local GlideClock = require("WhisperMessenger.UI.Shared.GlideClock")
local FakeUI = require("tests.helpers.fake_ui")

local FRAME = 1 / 60

local function build(duration)
  local factory = FakeUI.NewFactory()
  local case = { frame = factory.CreateFrame("Frame", "Clocked", nil), ticks = {}, done = 0, duration = duration }
  GlideClock.Run(case.frame, duration, function(t, p)
    case.ticks[#case.ticks + 1] = { t = t, p = p }
  end, function()
    case.done = case.done + 1
  end)
  return case
end

local function tick(case, seconds)
  local remaining = seconds
  while remaining > 0 and case.frame.scripts.OnUpdate do
    case.frame.scripts.OnUpdate(case.frame, math.min(FRAME, remaining))
    remaining = remaining - FRAME
  end
end

local function near(a, b)
  return math.abs(a - b) < 1e-9
end

return function()
  -- test_ticks_rise_then_done_fires_once_and_the_script_clears
  do
    local case = build(0.24)
    tick(case, 1)
    assert(#case.ticks > 3, "a tick per frame, got " .. #case.ticks)
    for i = 2, #case.ticks do
      assert(case.ticks[i].t > case.ticks[i - 1].t, "time only rises")
    end
    assert(case.ticks[#case.ticks].t < 1, "the end is onDone's, not a tick")
    assert(case.done == 1, "done once, got " .. case.done)
    assert(case.frame.scripts.OnUpdate == nil, "the clock clears itself")
  end

  -- test_ease_out_is_cubic
  do
    local case = build(4 / 30) -- two capped frames reach t = 0.5
    case.frame.scripts.OnUpdate(case.frame, 1 / 30)
    assert(near(case.ticks[1].t, 0.25) and near(case.ticks[1].p, 1 - 0.75 ^ 3), "t=0.25 gives 0.578125")
    case.frame.scripts.OnUpdate(case.frame, 1 / 30)
    assert(near(case.ticks[2].t, 0.5) and near(case.ticks[2].p, 0.875), "t=0.5 gives 0.875")
  end

  -- test_a_slow_frame_is_capped_instead_of_skipping_the_animation
  do
    local case = build(0.24)
    case.frame.scripts.OnUpdate(case.frame, 2)
    assert(case.frame.scripts.OnUpdate ~= nil and case.done == 0, "still running")
    assert(#case.ticks == 1 and near(case.ticks[1].t, (1 / 30) / 0.24), "moves on by one capped frame")
  end

  -- test_stop_ends_the_clock_without_done
  do
    local case = build(0.24)
    tick(case, 0.05)
    local seen = #case.ticks
    GlideClock.Stop(case.frame)
    assert(case.frame.scripts.OnUpdate == nil, "no script left")
    assert(#case.ticks == seen and case.done == 0, "stopped means silent")
    GlideClock.Stop(case.frame) -- stopping a stopped clock is safe
  end

  -- test_a_second_run_replaces_the_first
  do
    local case = build(0.24)
    local second = 0
    GlideClock.Run(case.frame, 0.24, function()
      second = second + 1
    end)
    tick(case, 0.1)
    assert(#case.ticks == 0 and second > 0, "only the newest run ticks")
  end

  -- test_done_is_optional
  do
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Frame", "Clocked", nil)
    GlideClock.Run(frame, 0.05, function() end)
    for _ = 1, 10 do
      if frame.scripts.OnUpdate then
        frame.scripts.OnUpdate(frame, FRAME)
      end
    end
    assert(frame.scripts.OnUpdate == nil, "ends without an onDone")
  end
end
