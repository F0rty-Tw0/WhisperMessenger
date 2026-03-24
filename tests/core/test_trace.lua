local trace = require("WhisperMessenger.Core.Trace")

return function()
  -- 1. trace is a callable table (not a plain function)
  assert(type(trace) == "table", "trace should be a table")
  local mt = getmetatable(trace)
  assert(mt and type(mt.__call) == "function", "trace should have __call metamethod")

  -- helper: capture print output during a callback
  local function withCapture(fn)
    local captured = {}
    local originalPrint = _G.print
    _G.print = function(...)
      table.insert(captured, { ... })
    end
    fn()
    _G.print = originalPrint
    return captured
  end

  -- 2. Disabled by default — trace("hello", "world") prints nothing
  local capturedDefault = withCapture(function()
    trace("hello", "world")
  end)
  assert(#capturedDefault == 0, "trace should not print when disabled by default")

  -- 3. isEnabled() returns false by default
  assert(trace.isEnabled() == false, "trace.isEnabled() should return false by default")

  -- enable for the remaining tests
  trace.enable()

  -- 4. When enabled, trace prints with [WM] prefix
  local captured = withCapture(function()
    trace("hello", "world")
  end)
  assert(#captured == 1, "trace should call print once when enabled")
  assert(captured[1][1] == "[WM]", "trace should prefix with [WM]")
  assert(captured[1][2] == "hello", "trace should pass first arg")
  assert(captured[1][3] == "world", "trace should pass second arg")

  -- 4. After disable(), calling trace("x") prints nothing
  trace.disable()
  local capturedDisabled = withCapture(function()
    trace("x")
  end)
  assert(#capturedDisabled == 0, "trace should not print when disabled")

  -- 5. isEnabled() returns false after disable
  assert(trace.isEnabled() == false, "trace.isEnabled() should return false after disable")

  -- 6. After enable(), calling trace("y") prints again
  trace.enable()
  local capturedEnabled = withCapture(function()
    trace("y")
  end)
  assert(#capturedEnabled == 1, "trace should print again after enable")
  assert(capturedEnabled[1][1] == "[WM]", "trace should still prefix with [WM] after re-enable")
  assert(capturedEnabled[1][2] == "y", "trace should pass arg after re-enable")

  -- 7. isEnabled() returns true after enable
  assert(trace.isEnabled() == true, "trace.isEnabled() should return true after enable")
end
