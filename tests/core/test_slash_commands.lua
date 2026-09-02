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
  local savedReplySlash1 = _G.SLASH_WHISPERMESSENGER_REPLY1
  local savedReplySlash2 = _G.SLASH_WHISPERMESSENGER_REPLY2
  local savedSlashCmdList = _G.SlashCmdList
  _G.SlashCmdList = _G.SlashCmdList or {}

  -- 1. Register returns true and sets up slash commands
  local toggleCalls = 0
  local replyCalls = 0
  local result = SlashCommands.Register({
    toggle = function()
      toggleCalls = toggleCalls + 1
    end,
    replyToLast = function()
      replyCalls = replyCalls + 1
    end,
  })
  assert(result == true, "Register should return true")
  assert(_G.SLASH_WHISPERMESSENGER1 == "/wmsg", "SLASH_WHISPERMESSENGER1 should be /wmsg")
  assert(_G.SLASH_WHISPERMESSENGER2 == "/whispermessenger", "SLASH_WHISPERMESSENGER2 should be /whispermessenger")
  assert(type(_G.SlashCmdList["WHISPERMESSENGER"]) == "function", "SlashCmdList.WHISPERMESSENGER should be a function")
  assert(_G.SLASH_WHISPERMESSENGER_REPLY1 == "/wr", "SLASH_WHISPERMESSENGER_REPLY1 should be /wr")
  assert(_G.SLASH_WHISPERMESSENGER_REPLY2 == "/wreply", "SLASH_WHISPERMESSENGER_REPLY2 should be /wreply")
  assert(type(_G.SlashCmdList["WHISPERMESSENGER_REPLY"]) == "function", "SlashCmdList.WHISPERMESSENGER_REPLY should be a function")

  local handler = _G.SlashCmdList["WHISPERMESSENGER"]

  -- 2. Removed command words behave like ordinary /wmsg invocations.
  local captured = withCapture(function()
    handler("debug")
    handler("mem")
    handler("memory")
  end)
  assert(toggleCalls == 3, "removed command words should toggle the messenger")
  assert(#captured == 0, "removed command words should not print status")

  -- 3. Empty arg still calls toggle handler
  handler("")
  assert(toggleCalls == 4, "empty command should still call toggle handler")

  -- 4. Reply command still calls reply-to-last handler
  _G.SlashCmdList["WHISPERMESSENGER_REPLY"]()
  assert(replyCalls == 1, "reply command should still call replyToLast handler")

  -- 5. Mythic no-op: slash commands remain registered (they are safe;
  --    the command handler guards mythic internally if needed)
  assert(_G.SLASH_WHISPERMESSENGER1 ~= nil, "SLASH_WHISPERMESSENGER1 should be set")
  assert(_G.SlashCmdList["WHISPERMESSENGER"] ~= nil, "SlashCmdList.WHISPERMESSENGER should be set")

  -- Cleanup
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  _G.SLASH_WHISPERMESSENGER_REPLY1 = savedReplySlash1
  _G.SLASH_WHISPERMESSENGER_REPLY2 = savedReplySlash2
  _G.SlashCmdList = savedSlashCmdList
end
