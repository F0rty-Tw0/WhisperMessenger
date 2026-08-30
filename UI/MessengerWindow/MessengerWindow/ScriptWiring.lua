local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScriptWiring = {}

function ScriptWiring.Wire(options)
  options = options or {}

  local windowScripts = options.windowScripts
  local result = windowScripts.WireButtons(options.buttonsRefs, options.buttonsCallbacks) or {}
  local frameResult = windowScripts.WireFrame(options.frameRefs, options.frameCallbacks)
  if frameResult and frameResult.withSizeChangedRelayoutSuppressed then
    result.withSizeChangedRelayoutSuppressed = frameResult.withSizeChangedRelayoutSuppressed
  end
  return result
end

ns.MessengerWindowScriptWiring = ScriptWiring

return ScriptWiring
