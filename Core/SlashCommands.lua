local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local trace = ns.trace or require("WhisperMessenger.Core.Trace")

local SlashCommands = {}
ns.SlashCommands = SlashCommands

function SlashCommands.Register(handlers)
  handlers = handlers or {}
  SlashCmdList = SlashCmdList or {}
  SLASH_WHISPERMESSENGER1 = "/wmsg"
  SLASH_WHISPERMESSENGER2 = "/whispermessenger"
  SlashCmdList.WHISPERMESSENGER = function(input)
    local cmd = type(input) == "string" and string.lower(string.match(input, "^%s*(%S+)") or "") or ""

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

  trace("slash registered", "/wmsg", "/whispermessenger")
  return true
end

return SlashCommands
