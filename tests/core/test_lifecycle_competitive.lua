local Competitive = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Competitive")

local function makeHarness()
  local calls = { suspend = 0, resume = 0 }
  local Bootstrap = {
    _inMythicContent = false,
    runtime = {
      suspend = function()
        calls.suspend = calls.suspend + 1
      end,
      resume = function()
        calls.resume = calls.resume + 1
      end,
    },
  }
  local deps = { trace = function() end }
  return Bootstrap, deps, calls
end

return function()
  -- test_challenge_mode_start_suspends_once
  do
    local Bootstrap, deps, calls = makeHarness()

    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_START", deps)
    assert(calls.suspend == 1, "first CHALLENGE_MODE_START suspends")
    assert(Bootstrap._inMythicContent == true, "mythic flag set")

    -- A duplicate suspend would clobber _wasVisibleBeforeMythic (the window
    -- is already hidden by the first suspend), so it must be skipped.
    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_START", deps)
    assert(calls.suspend == 1, "already-suspended CHALLENGE_MODE_START must not suspend again; got: " .. tostring(calls.suspend))
  end

  -- test_challenge_mode_completed_resumes_only_when_suspended
  do
    local Bootstrap, deps, calls = makeHarness()

    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_COMPLETED", deps)
    assert(calls.resume == 0, "COMPLETED without a prior suspend must not resume; got: " .. tostring(calls.resume))

    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_START", deps)
    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_COMPLETED", deps)
    assert(calls.resume == 1, "COMPLETED after a suspend resumes once")
    assert(Bootstrap._inMythicContent == false, "mythic flag cleared")
  end
end
