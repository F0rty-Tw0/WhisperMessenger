local SlashCommands = require("WhisperMessenger.Core.SlashCommands")

return function()

  -- test_wr_slash_registered_and_invokes_reply_handler

  -- /wr is the taint-safe reply-to-last-whisper command. It bypasses
  -- Blizzard's ChatEdit_SetLastTellTarget (which gets tainted during M+
  -- when a whisper arrives with a secret-string sender). Instead it uses
  -- runtime.lastIncomingWhisperKey via our own auto-open path.
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
  local savedReplySlash1 = _G.SLASH_WHISPERMESSENGER_REPLY1
  local savedReplySlash2 = _G.SLASH_WHISPERMESSENGER_REPLY2
  local savedSlashCmdList = _G.SlashCmdList
  _G.SlashCmdList = {}

  local replied = 0
  SlashCommands.Register({
    replyToLast = function()
      replied = replied + 1
    end,
  })

  assert(_G.SLASH_WHISPERMESSENGER_REPLY1 == "/wr", "SLASH_WHISPERMESSENGER_REPLY1 should be /wr")
  assert(_G.SLASH_WHISPERMESSENGER_REPLY2 == "/wreply", "SLASH_WHISPERMESSENGER_REPLY2 should be /wreply")
  assert(
    type(_G.SlashCmdList["WHISPERMESSENGER_REPLY"]) == "function",
    "SlashCmdList.WHISPERMESSENGER_REPLY should be registered"
  )

  _G.SlashCmdList["WHISPERMESSENGER_REPLY"]("")
  assert(replied == 1, "invoking /wr should call replyToLast handler exactly once, got " .. replied)

  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  _G.SLASH_WHISPERMESSENGER_REPLY1 = savedReplySlash1
  _G.SLASH_WHISPERMESSENGER_REPLY2 = savedReplySlash2
  _G.SlashCmdList = savedSlashCmdList
end
