local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local function trace(...)
  if type(_G.print) == "function" then
    _G.print("[WM]", ...)
  end
end

local SlashCommands = {}
ns.SlashCommands = SlashCommands

function SlashCommands.Register(handlers)
  handlers = handlers or {}
  SlashCmdList = SlashCmdList or {}
  SLASH_WHISPERMESSENGER1 = "/wmsg"
  SLASH_WHISPERMESSENGER2 = "/whispermessenger"
  SlashCmdList.WHISPERMESSENGER = function()
    trace("slash invoked")
    if handlers.toggle then
      handlers.toggle()
    end
  end

  trace("slash registered", "/wmsg", "/whispermessenger")
  return true
end

return SlashCommands
