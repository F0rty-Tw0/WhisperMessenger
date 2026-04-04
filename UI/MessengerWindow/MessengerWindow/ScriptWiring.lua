local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScriptWiring = {}

function ScriptWiring.Wire(options)
  options = options or {}

  local windowScripts = options.windowScripts
  windowScripts.WireButtons(options.buttonsRefs, options.buttonsCallbacks)
  windowScripts.WireFrame(options.frameRefs, options.frameCallbacks)
end

ns.MessengerWindowScriptWiring = ScriptWiring

return ScriptWiring
