local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local trace = ns.trace or require("WhisperMessenger.Core.Trace")

local SlashCommands = {}
ns.SlashCommands = SlashCommands

function SlashCommands.Register(handlers)
  handlers = handlers or {}

  local function handleCommand(msg)
    local cmd = type(msg) == "string" and string.lower(msg) or ""

    if cmd == "mem" or cmd == "memory" then
      if handlers.memoryReport then
        handlers.memoryReport()
      end
      return
    end

    if cmd == "debug" then
      if trace.isEnabled() then
        trace.disable()
      else
        trace.enable()
      end
      local status = trace.isEnabled() and "ON" or "OFF"
      if type(_G.print) == "function" then
        _G.print("[WM] Debug tracing: " .. status)
      end
      return
    end

    trace("slash invoked")
    if handlers.toggle then
      handlers.toggle()
    end
  end

  -- Register through the standard SLASH_*/SlashCmdList mechanism.
  -- Do NOT reassign SlashCmdList itself — use _G.SlashCmdList for indexing
  -- to avoid tainting the table reference.
  if type(_G.SlashCmdList) == "table" then
    _G.SLASH_WHISPERMESSENGER1 = "/wmsg"
    _G.SLASH_WHISPERMESSENGER2 = "/whispermessenger"
    _G.SlashCmdList["WHISPERMESSENGER"] = handleCommand
  end

  trace("slash registered /wmsg /whispermessenger")
  return true
end

return SlashCommands
