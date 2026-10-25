local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- "Mark all read" also reaches other addons' alerts: their widget preview
-- goes, each registered panel hears onMarkAllRead, and the icons re-read
-- badge(). The runtime fields are read when this runs; they are bound after
-- the window callbacks are built.
local AddonAlerts = {}

function AddonAlerts.Clear(runtime)
  if runtime.externalPreview then
    runtime.externalPreview.clear()
  end
  if runtime.panelRegistry then
    runtime.panelRegistry.markAllRead()
  end
  if runtime.updateIconSurfaces then
    runtime.updateIconSurfaces()
  end
end

ns.BootstrapWindowRuntimeAddonAlerts = AddonAlerts
return AddonAlerts
