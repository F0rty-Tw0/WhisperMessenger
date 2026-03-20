local trace = require("WhisperMessenger.Core.Trace")

return function()
  assert(type(trace) == "function", "trace should be a function")

  local captured = {}
  local originalPrint = _G.print
  _G.print = function(...)
    table.insert(captured, { ... })
  end

  trace("hello", "world")

  _G.print = originalPrint

  assert(#captured == 1, "trace should call print once")
  assert(captured[1][1] == "[WM]", "trace should prefix with [WM]")
  assert(captured[1][2] == "hello", "trace should pass first arg")
  assert(captured[1][3] == "world", "trace should pass second arg")
end
