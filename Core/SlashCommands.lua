local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SlashCommands = {}
ns.SlashCommands = SlashCommands

function SlashCommands.Register(handlers)
  handlers = handlers or {}

  local function handleCommand(_msg)
    if handlers.toggle then
      handlers.toggle()
    end
  end

  -- Taint-safe reply-to-last-whisper: routes through our messenger and
  -- runtime.lastIncomingWhisperKey, bypassing Blizzard's ChatEdit_SetLastTellTarget
  -- which gets tainted during M+ when a secret-string sender is stored.
  local function handleReplyCommand()
    if handlers.replyToLast then
      handlers.replyToLast()
    end
  end

  -- Register through the standard SLASH_*/SlashCmdList mechanism.
  -- Do NOT reassign SlashCmdList itself — use _G.SlashCmdList for indexing
  -- to avoid tainting the table reference.
  if type(_G.SlashCmdList) == "table" then
    _G.SLASH_WHISPERMESSENGER1 = "/wmsg"
    _G.SLASH_WHISPERMESSENGER2 = "/whispermessenger"
    _G.SlashCmdList["WHISPERMESSENGER"] = handleCommand

    _G.SLASH_WHISPERMESSENGER_REPLY1 = "/wr"
    _G.SLASH_WHISPERMESSENGER_REPLY2 = "/wreply"
    _G.SlashCmdList["WHISPERMESSENGER_REPLY"] = handleReplyCommand
  end

  return true
end

return SlashCommands
