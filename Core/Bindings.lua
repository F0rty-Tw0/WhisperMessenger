local _addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

BINDING_NAME_WHISPERMESSENGER_TOGGLE = "Toggle Window"

function WhisperMessenger_Toggle()
  if ns.Bootstrap and ns.Bootstrap.runtime and ns.Bootstrap.runtime.toggle then
    ns.Bootstrap.runtime.toggle()
  end
end
