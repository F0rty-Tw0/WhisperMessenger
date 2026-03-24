-- Setup: mock trace before requiring SlashCommands
local mockEnabled = false
local mockCalls = {}
local mockTrace = setmetatable({}, {
  __call = function(_self, ...)
    table.insert(mockCalls, { ... })
  end,
})
function mockTrace.enable()
  mockEnabled = true
end
function mockTrace.disable()
  mockEnabled = false
end
function mockTrace.isEnabled()
  return mockEnabled
end

-- Pre-load mock so SlashCommands picks it up via ns.trace or require(...)
package.loaded["WhisperMessenger.Core.Trace"] = mockTrace
package.loaded["Core.Trace"] = mockTrace

-- Force fresh load of SlashCommands
package.loaded["WhisperMessenger.Core.SlashCommands"] = nil
package.loaded["Core.SlashCommands"] = nil

local SlashCommands = require("WhisperMessenger.Core.SlashCommands")

return function()
  -- Reset globals before each run
  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil

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

  -- 1. Register returns true
  local result = SlashCommands.Register({})
  assert(result == true, "Register should return true")

  -- 2. /wmsg debug toggles debug OFF when it was ON
  mockEnabled = true
  local invoke = _G.SlashCmdList.WHISPERMESSENGER
  assert(type(invoke) == "function", "SlashCmdList.WHISPERMESSENGER should be a function")

  withCapture(function()
    invoke("debug")
  end)
  assert(mockEnabled == false, "debug command should disable trace when it was enabled")

  -- 3. /wmsg debug toggles debug ON when it was OFF
  mockEnabled = false
  withCapture(function()
    invoke("debug")
  end)
  assert(mockEnabled == true, "debug command should enable trace when it was disabled")

  -- 4. /wmsg debug prints a status message
  mockEnabled = true
  local captured = withCapture(function()
    invoke("debug")
  end)
  assert(#captured == 1, "debug command should print exactly one message")
  local msg = captured[1][1]
  assert(type(msg) == "string", "debug command should print a string")
  assert(string.find(msg, "OFF"), "debug command should print OFF after disabling")

  -- 5. /wmsg mem still calls memoryReport handler
  local memCalled = false
  SlashCommands.Register({
    memoryReport = function()
      memCalled = true
    end,
  })
  _G.SlashCmdList.WHISPERMESSENGER("mem")
  assert(memCalled, "mem command should still call memoryReport handler")

  -- 6. Default (no cmd) still calls toggle handler
  local toggleCalled = false
  SlashCommands.Register({
    toggle = function()
      toggleCalled = true
    end,
  })
  _G.SlashCmdList.WHISPERMESSENGER("")
  assert(toggleCalled, "empty command should still call toggle handler")
end
