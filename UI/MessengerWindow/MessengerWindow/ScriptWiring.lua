local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScriptWiring = {}

function ScriptWiring.Wire(options)
  options = options or {}

  local windowScripts = options.windowScripts
  local buttonsResult = windowScripts.WireButtons(options.buttonsRefs, options.buttonsCallbacks)
  windowScripts.WireFrame(options.frameRefs, options.frameCallbacks)
  return buttonsResult or {}
end

ns.MessengerWindowScriptWiring = ScriptWiring

return ScriptWiring
