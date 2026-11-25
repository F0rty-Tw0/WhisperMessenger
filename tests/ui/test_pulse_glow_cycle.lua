-- PulseGlow.Create takes options.cycleSeconds: the fade-in, hold and fade-out
-- keep their shares of the cycle; absent keeps the 1.75 s cycle.
local AnimatedFactory = require("tests.helpers.animated_factory")
local PulseGlow = require("WhisperMessenger.UI.ToggleIcon.PulseGlow")

local function cycleLength(options)
  local factory = AnimatedFactory.newAnimatedFactory()
  local host = factory.CreateFrame("Frame", "Host", nil)
  local pulse = PulseGlow.Create(factory, host, options)
  local sum = 0
  for _, anim in ipairs(pulse.animation.animations) do
    sum = sum + anim.duration + anim.endDelay
  end
  return sum
end

return function()
  local function test_cycle_seconds_stretch_the_pulse()
    local sum = cycleLength({ cycleSeconds = 3 })
    assert(math.abs(sum - 3) < 1e-9, "expected a 3 s cycle, got " .. sum)
  end

  local function test_default_cycle_is_unchanged()
    local sum = cycleLength()
    assert(math.abs(sum - 1.75) < 1e-9, "expected the 1.75 s cycle, got " .. sum)
  end

  test_cycle_seconds_stretch_the_pulse()
  test_default_cycle_is_unchanged()
end
