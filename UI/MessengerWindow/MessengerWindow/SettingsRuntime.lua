local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SettingsPanels = ns.MessengerWindowSettingsPanels or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")
local GeneralSettings = ns.GeneralSettings or require("WhisperMessenger.UI.MessengerWindow.GeneralSettings")
local AppearanceSettings = ns.AppearanceSettings or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local BehaviorSettings = ns.BehaviorSettings or require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local NotificationSettings = ns.NotificationSettings or require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
local IconSettings = ns.IconSettings or require("WhisperMessenger.UI.MessengerWindow.IconSettings")
local PatchNotesSettings = ns.PatchNotesSettings or require("WhisperMessenger.UI.MessengerWindow.PatchNotesSettings")
local PatchNotes = ns.PatchNotes or require("WhisperMessenger.Core.PatchNotes")

local SettingsRuntime = {}

function SettingsRuntime.Create(factory, options)
  options = options or {}

  local settingsPanelsCreate = options.settingsPanelsCreate or SettingsPanels.Create
  local generalCreate = options.generalCreate or GeneralSettings.Create
  local appearanceCreate = options.appearanceCreate or AppearanceSettings.Create
  local behaviorCreate = options.behaviorCreate or BehaviorSettings.Create
  local notificationCreate = options.notificationCreate or NotificationSettings.Create
  local iconCreate = options.iconCreate or IconSettings.Create
  local patchNotesCreate = options.patchNotesCreate or PatchNotesSettings.Create

  local currentConversation = nil
  local currentComposer = nil
  local refreshThemeVisuals
  local runtime = {}
  local panelKeys = { "generalPanel", "appearancePanel", "behaviorPanel", "notificationsPanel", "iconsPanel", "patchNotesPanel" }
  local settingsKeys = { "generalSettings", "appearanceSettings", "behaviorSettings", "notificationSettings", "iconSettings", "patchNotesSettings" }
  local function onSettingChanged(key, value)
    if options.onSettingChanged then
      options.onSettingChanged(key, value)
    end
    if (key == "themePreset" or key == "fontSize") and refreshThemeVisuals then
      refreshThemeVisuals()
    end
  end
  local function onPanelCreated(index, panel, settings)
    runtime[panelKeys[index]] = panel
    runtime[settingsKeys[index]] = settings
    if options.onPanelCreated then
      options.onPanelCreated(index, panel, settings)
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
    iconCreate = iconCreate,
    patchNotesCreate = patchNotesCreate,
    patchNotes = options.patchNotes or PatchNotes,
    onPanelCreated = onPanelCreated,
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

  runtime.settingsPanels = settingsPanels.settingsPanels
  runtime.getPanel = settingsPanels.getPanel
  runtime.getSettings = settingsPanels.getSettings
  runtime.generalPanel = settingsPanels.generalPanel
  runtime.generalSettings = settingsPanels.generalSettings
  runtime.appearancePanel = settingsPanels.appearancePanel
  runtime.appearanceSettings = settingsPanels.appearanceSettings
  runtime.behaviorPanel = settingsPanels.behaviorPanel
  runtime.behaviorSettings = settingsPanels.behaviorSettings
  runtime.notificationsPanel = settingsPanels.notificationsPanel
  runtime.notificationSettings = settingsPanels.notificationSettings
  runtime.iconsPanel = settingsPanels.iconsPanel
  runtime.iconSettings = settingsPanels.iconSettings
  runtime.patchNotesPanel = settingsPanels.patchNotesPanel
  runtime.patchNotesSettings = settingsPanels.patchNotesSettings
  runtime.refreshThemeVisuals = refreshThemeVisuals
  runtime.setThemeTargets = function(conversation, composer)
    currentConversation = conversation
    currentComposer = composer
  end
  return runtime
end

ns.MessengerWindowSettingsRuntime = SettingsRuntime

return SettingsRuntime
