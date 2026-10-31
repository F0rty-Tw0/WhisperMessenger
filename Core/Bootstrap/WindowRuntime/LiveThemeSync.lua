local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Keeps a live theme preset (EllesmereUI) in step with its source: when the
-- source's look arrives at login or changes, the preset is applied again,
-- through the settings handler once the window exists so it repaints. Before
-- that, repaintIcons repaints the widget and minimap button, which already exist.
local LiveThemeSync = {}

function LiveThemeSync.Install(bridge, theme, getOnSettingChanged, repaintIcons)
  if type(bridge) ~= "table" or type(bridge.OnChange) ~= "function" or type(bridge.Install) ~= "function" then
    return false
  end
  bridge.OnChange(function()
    local key = theme.GetPreset and theme.GetPreset()
    if not (theme.IsLivePreset and theme.IsLivePreset(key)) then
      return
    end
    local onSettingChanged = getOnSettingChanged()
    if onSettingChanged then
      onSettingChanged("themePreset", key)
    elseif theme.SetPreset then
      theme.SetPreset(key)
      if repaintIcons then
        repaintIcons()
      end
    end
  end)
  return bridge.Install()
end

ns.BootstrapWindowRuntimeLiveThemeSync = LiveThemeSync
return LiveThemeSync
