local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local KeySettle = ns.KeySettle or require("WhisperMessenger.Core.KeySettle")

BINDING_NAME_WHISPERMESSENGER_TOGGLE = "Toggle Window"

function WhisperMessenger_Toggle()
  KeySettle.After(function()
    if ns.Bootstrap and ns.Bootstrap.runtime and ns.Bootstrap.runtime.toggle then
      ns.Bootstrap.runtime.toggle()
    end
  end)
end
