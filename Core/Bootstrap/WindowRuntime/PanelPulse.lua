local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Opening the panel of the addon that owns the external preview ends the
-- preview's pulse. The preview itself stays until its owner hides it.
local PanelPulse = {}

function PanelPulse.OnPanelShown(holder, updateIconSurfaces)
  return function(key)
    local entry = holder.get()
    if entry == nil or holder.keyOf() ~= key or entry.pulse ~= true then
      return
    end
    entry.pulse = false
    updateIconSurfaces()
  end
end

ns.BootstrapWindowRuntimePanelPulse = PanelPulse
return PanelPulse
