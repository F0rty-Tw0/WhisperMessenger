local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local KeySettle = ns.KeySettle or require("WhisperMessenger.Core.KeySettle")

BINDING_NAME_WHISPERMESSENGER_TOGGLE = "Toggle Window"

-- The quiet /who for the chat the toggle opens onto runs inside the key press:
-- KeySettle.After defers the toggle itself out of the hardware event. WhoTriggers
-- loads after this file, so it is read at call time, never required here.
local function askWhoForOpenTarget()
  local triggers = ns.BootstrapWindowRuntimeWhoTriggers
  local runtime = ns.Bootstrap and ns.Bootstrap.runtime
  if triggers == nil or runtime == nil or type(runtime.toggleTargetKey) ~= "function" then
    return
  end

  local targetKey = runtime.toggleTargetKey()
  if targetKey ~= nil then
    triggers.AskFor(runtime, targetKey)
  end
end

function WhisperMessenger_Toggle()
  askWhoForOpenTarget()
  KeySettle.After(function()
    if ns.Bootstrap and ns.Bootstrap.runtime and ns.Bootstrap.runtime.toggle then
      ns.Bootstrap.runtime.toggle()
    end
  end)
end
