local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SettingsRuntime = ns.MessengerWindowSettingsRuntime or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsRuntime")

local SettingsPanelsBootstrap = {}

function SettingsPanelsBootstrap.Create(factory, options)
  options = options or {}

  local runtimeCreate = options.settingsRuntimeCreate or SettingsRuntime.Create

  return runtimeCreate(factory, {
    parent = options.parent,
    settingsConfig = options.settingsConfig or {},
    storeConfig = options.storeConfig or {},
    onSettingChanged = options.onSettingChanged,
    theme = options.theme,
    chrome = options.chrome,
    layout = options.layout,
  })
end

ns.MessengerWindowSettingsPanelsBootstrap = SettingsPanelsBootstrap

return SettingsPanelsBootstrap
