local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local SettingsPanels = {}

local SETTINGS_RIGHT_PADDING_TRIM = 20
local SETTINGS_SCROLLBAR_RESERVE = 4

local function paneInnerWidth(outerWidth)
  local padding = (Theme.CONTENT_PADDING or 16) * 2
  if type(outerWidth) ~= "number" or outerWidth <= 0 then
    return nil
  end
  return outerWidth - padding + SETTINGS_RIGHT_PADDING_TRIM - SETTINGS_SCROLLBAR_RESERVE
end

local function createSettingsPanel(factory, parent, createSettingsView, config, onSettingChanged)
  local panel = factory.CreateFrame("Frame", nil, parent)
  panel:SetAllPoints(parent)
  local settings = createSettingsView(factory, panel, config, {
    onChange = onSettingChanged,
  })
  if settings and settings.refreshLayout then
    if panel.SetScript then
      panel:SetScript("OnSizeChanged", function(_, w)
        local inner = paneInnerWidth(w)
        if inner then
          settings.refreshLayout(inner)
        end
      end)
    end
    if parent.GetWidth then
      local initialWidth = parent:GetWidth()
      local inner = paneInnerWidth(initialWidth)
      if inner then
        settings.refreshLayout(inner)
      end
    end
  end
  return panel, settings
end

function SettingsPanels.Create(factory, options)
  options = options or {}

  local parent = options.parent
  local settingsConfig = options.settingsConfig or {}
  local storeConfig = options.storeConfig or {}
  local onSettingChanged = options.onSettingChanged or function() end

  local generalPanel, generalSettings = createSettingsPanel(factory, parent, options.generalCreate, {
    maxMessagesPerConversation = storeConfig.maxMessagesPerConversation or 200,
    maxConversations = storeConfig.maxConversations or 100,
    messageMaxAge = storeConfig.messageMaxAge or 86400,
    clearOnLogout = settingsConfig.clearOnLogout,
    hideMessagePreview = settingsConfig.hideMessagePreview,
  }, onSettingChanged)

  local appearancePanel, appearanceSettings = createSettingsPanel(factory, parent, options.appearanceCreate, {
    themePreset = settingsConfig.themePreset,
    fontFamily = settingsConfig.fontFamily,
    fontSize = settingsConfig.fontSize,
    fontOutline = settingsConfig.fontOutline,
    fontColor = settingsConfig.fontColor,
    windowOpacityInactive = settingsConfig.windowOpacityInactive,
    windowOpacityActive = settingsConfig.windowOpacityActive,
    nativeChrome = settingsConfig.nativeChrome,
  }, onSettingChanged)

  local behaviorPanel, behaviorSettings = createSettingsPanel(factory, parent, options.behaviorCreate, {
    dimWhenMoving = settingsConfig.dimWhenMoving,
    autoFocusComposer = settingsConfig.autoFocusComposer,
    hideFromDefaultChat = settingsConfig.hideFromDefaultChat,
    autoOpenIncoming = settingsConfig.autoOpenIncoming,
    autoOpenOutgoing = settingsConfig.autoOpenOutgoing,
    doubleEscapeToClose = settingsConfig.doubleEscapeToClose,
  }, onSettingChanged)

  local notificationsPanel, notificationSettings = createSettingsPanel(factory, parent, options.notificationCreate, {
    badgePulse = settingsConfig.badgePulse,
    playSoundOnWhisper = settingsConfig.playSoundOnWhisper,
    showUnreadBadge = settingsConfig.showUnreadBadge,
    iconSize = settingsConfig.iconSize,
    iconDesaturated = settingsConfig.iconDesaturated,
  }, onSettingChanged)

  local function refreshTheme(theme, context)
    context = context or {}

    if context.chrome and context.chrome.applyTheme then
      context.chrome.applyTheme(theme)
    end
    if context.layout and context.layout.applyTheme then
      context.layout.applyTheme(theme)
    end
    if context.conversation and context.conversation.refreshTheme then
      context.conversation.refreshTheme()
    end
    if context.composer and context.composer.refreshTheme then
      context.composer.refreshTheme()
    end

    for _, settingsView in ipairs({ generalSettings, appearanceSettings, behaviorSettings, notificationSettings }) do
      if settingsView and settingsView.refreshTheme then
        settingsView.refreshTheme(theme)
      end
    end
  end

  local function refreshLayout(outerWidth)
    local inner = paneInnerWidth(outerWidth)
    if not inner then
      return
    end
    for _, settingsView in ipairs({ generalSettings, appearanceSettings, behaviorSettings, notificationSettings }) do
      if settingsView and settingsView.refreshLayout then
        settingsView.refreshLayout(inner)
      end
    end
  end

  return {
    generalPanel = generalPanel,
    generalSettings = generalSettings,
    appearancePanel = appearancePanel,
    appearanceSettings = appearanceSettings,
    behaviorPanel = behaviorPanel,
    behaviorSettings = behaviorSettings,
    notificationsPanel = notificationsPanel,
    notificationSettings = notificationSettings,
    refreshTheme = refreshTheme,
    refreshLayout = refreshLayout,
  }
end

ns.MessengerWindowSettingsPanels = SettingsPanels

return SettingsPanels
