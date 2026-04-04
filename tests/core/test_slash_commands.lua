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
  -- helper: capture print output during a callback
  local function withCapture(fn)
    local captured = {}
    local originalPrint = _G.print
    rawset(_G, "print", function(...)
      table.insert(captured, { ... })
    end)
    fn()
    rawset(_G, "print", originalPrint)
    return captured
  end

  -- Save globals for cleanup
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
  local savedSlashCmdList = _G.SlashCmdList
  _G.SlashCmdList = _G.SlashCmdList or {}

  -- 1. Register returns true and sets up slash commands
  local result = SlashCommands.Register({})
  assert(result == true, "Register should return true")
  assert(_G.SLASH_WHISPERMESSENGER1 == "/wmsg", "SLASH_WHISPERMESSENGER1 should be /wmsg")
  assert(_G.SLASH_WHISPERMESSENGER2 == "/whispermessenger", "SLASH_WHISPERMESSENGER2 should be /whispermessenger")
  assert(type(_G.SlashCmdList["WHISPERMESSENGER"]) == "function", "SlashCmdList.WHISPERMESSENGER should be a function")

  local handler = _G.SlashCmdList["WHISPERMESSENGER"]

  -- 2. "debug" toggles debug OFF when it was ON
  mockEnabled = true
  withCapture(function()
    handler("debug")
  end)
  assert(mockEnabled == false, "debug command should disable trace when it was enabled")

  -- 3. "debug" toggles debug ON when it was OFF
  mockEnabled = false
  withCapture(function()
    handler("debug")
  end)
  assert(mockEnabled == true, "debug command should enable trace when it was disabled")

  -- 4. "debug" prints a status message
  mockEnabled = true
  local captured = withCapture(function()
    handler("debug")
  end)
  assert(#captured == 1, "debug command should print exactly one message")
  local msg = captured[1][1]
  assert(type(msg) == "string", "debug command should print a string")
  assert(string.find(msg, "OFF"), "debug command should print OFF after disabling")

  -- 5. "mem" still calls memoryReport handler
  local memCalled = false
  SlashCommands.Register({
    memoryReport = function()
      memCalled = true
    end,
  })
  handler = _G.SlashCmdList["WHISPERMESSENGER"]
  handler("mem")
  assert(memCalled, "mem command should still call memoryReport handler")

  -- 6. Empty arg still calls toggle handler
  local toggleCalled = false
  SlashCommands.Register({
    toggle = function()
      toggleCalled = true
    end,
  })
  handler = _G.SlashCmdList["WHISPERMESSENGER"]
  handler("")
  assert(toggleCalled, "empty command should still call toggle handler")

  -- 7. Mythic no-op: slash commands remain registered (they are safe;
  --    the command handler guards mythic internally if needed)
  assert(_G.SLASH_WHISPERMESSENGER1 ~= nil, "SLASH_WHISPERMESSENGER1 should be set")
  assert(_G.SlashCmdList["WHISPERMESSENGER"] ~= nil, "SlashCmdList.WHISPERMESSENGER should be set")

  -- Cleanup
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  _G.SlashCmdList = savedSlashCmdList
end
