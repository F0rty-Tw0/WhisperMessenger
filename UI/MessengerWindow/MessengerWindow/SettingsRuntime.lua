local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SettingsPanels = ns.MessengerWindowSettingsPanels
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")
local GeneralSettings = ns.GeneralSettings or require("WhisperMessenger.UI.MessengerWindow.GeneralSettings")
local AppearanceSettings = ns.AppearanceSettings or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local BehaviorSettings = ns.BehaviorSettings or require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local NotificationSettings = ns.NotificationSettings
  or require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")

local SettingsRuntime = {}

function SettingsRuntime.Create(factory, options)
  options = options or {}

  local settingsPanelsCreate = options.settingsPanelsCreate or SettingsPanels.Create
  local generalCreate = options.generalCreate or GeneralSettings.Create
  local appearanceCreate = options.appearanceCreate or AppearanceSettings.Create
  local behaviorCreate = options.behaviorCreate or BehaviorSettings.Create
  local notificationCreate = options.notificationCreate or NotificationSettings.Create

  local currentConversation = nil
  local currentComposer = nil
  local refreshThemeVisuals
  local function onSettingChanged(key, value)
    if options.onSettingChanged then
      options.onSettingChanged(key, value)
    end
    if key == "themePreset" and refreshThemeVisuals then
      refreshThemeVisuals()
    end
  end

  local settingsPanels = settingsPanelsCreate(factory, {
    parent = options.parent,
    settingsConfig = options.settingsConfig or {},
    storeConfig = options.storeConfig or {},
    onSettingChanged = onSettingChanged,
    generalCreate = generalCreate,
    appearanceCreate = appearanceCreate,
    behaviorCreate = behaviorCreate,
    notificationCreate = notificationCreate,
  })

  refreshThemeVisuals = function()
    settingsPanels.refreshTheme(options.theme, {
      chrome = options.chrome,
      layout = options.layout,
      conversation = currentConversation,
      composer = currentComposer,
    })
  end
  refreshThemeVisuals()

  return {
    generalPanel = settingsPanels.generalPanel,
    generalSettings = settingsPanels.generalSettings,
    appearancePanel = settingsPanels.appearancePanel,
    appearanceSettings = settingsPanels.appearanceSettings,
    behaviorPanel = settingsPanels.behaviorPanel,
    behaviorSettings = settingsPanels.behaviorSettings,
    notificationsPanel = settingsPanels.notificationsPanel,
    notificationSettings = settingsPanels.notificationSettings,
    refreshThemeVisuals = refreshThemeVisuals,
    setThemeTargets = function(conversation, composer)
      currentConversation = conversation
      currentComposer = composer
    end,
  }
end

ns.MessengerWindowSettingsRuntime = SettingsRuntime

return SettingsRuntime
