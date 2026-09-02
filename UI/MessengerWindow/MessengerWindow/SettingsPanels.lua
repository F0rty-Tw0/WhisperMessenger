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
  -- Propagate the inner panel's bottom marker up to the wrapper so the
  -- options scrollview's per-tab content sizing (in WindowScripts/Buttons)
  -- can find it. The inner frame uses SetAllPoints(panel), so its TOPLEFT
  -- aligns with the wrapper's TOPLEFT — the SetPoint-chain walk gives the
  -- same y-down offset whether we start from the wrapper or the inner.
  if settings and settings.frame and settings.frame._wmBottomMarker then
    panel._wmBottomMarker = settings.frame._wmBottomMarker
  end
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
  local definitions = {
    {
      panelKey = "generalPanel",
      settingsKey = "generalSettings",
      create = options.generalCreate,
      config = {
        maxMessagesPerConversation = storeConfig.maxMessagesPerConversation or 200,
        maxConversations = storeConfig.maxConversations or 100,
        messageMaxAge = storeConfig.messageMaxAge or 86400,
        clearOnLogout = settingsConfig.clearOnLogout,
        hideMessagePreview = settingsConfig.hideMessagePreview,
        timeFormat = settingsConfig.timeFormat,
        timeSource = settingsConfig.timeSource,
        interfaceLanguage = settingsConfig.interfaceLanguage,
      },
    },
    {
      panelKey = "appearancePanel",
      settingsKey = "appearanceSettings",
      create = options.appearanceCreate,
      config = {
        themePreset = settingsConfig.themePreset,
        windowScale = settingsConfig.windowScale,
        fontFamily = settingsConfig.fontFamily,
        fontSize = settingsConfig.fontSize,
        fontOutline = settingsConfig.fontOutline,
        fontColor = settingsConfig.fontColor,
        bubbleColorPreset = settingsConfig.bubbleColorPreset,
        windowOpacityInactive = settingsConfig.windowOpacityInactive,
        windowOpacityActive = settingsConfig.windowOpacityActive,
        nativeChrome = settingsConfig.nativeChrome,
      },
    },
    {
      panelKey = "behaviorPanel",
      settingsKey = "behaviorSettings",
      create = options.behaviorCreate,
      config = {
        dimWhenMoving = settingsConfig.dimWhenMoving,
        autoFocusComposer = settingsConfig.autoFocusComposer,
        hideFromDefaultChat = settingsConfig.hideFromDefaultChat,
        autoOpenIncoming = settingsConfig.autoOpenIncoming,
        autoOpenOutgoing = settingsConfig.autoOpenOutgoing,
        hideOnCombat = settingsConfig.hideOnCombat,
        doubleEscapeToClose = settingsConfig.doubleEscapeToClose,
        showGroupChats = settingsConfig.showGroupChats,
      },
    },
    {
      panelKey = "notificationsPanel",
      settingsKey = "notificationSettings",
      create = options.notificationCreate,
      config = {
        playSoundOnWhisper = settingsConfig.playSoundOnWhisper,
        notificationSound = settingsConfig.notificationSound,
      },
    },
    {
      panelKey = "iconsPanel",
      settingsKey = "iconSettings",
      create = options.iconCreate,
      config = {
        badgePulse = settingsConfig.badgePulse,
        showUnreadBadge = settingsConfig.showUnreadBadge,
        iconSize = settingsConfig.iconSize,
        iconDesaturated = settingsConfig.iconDesaturated,
        lockToggleIcon = settingsConfig.lockToggleIcon,
        shareWidgetPosition = settingsConfig.shareWidgetPosition,
        widgetTransparency = settingsConfig.widgetTransparency,
        showWidgetMessagePreview = settingsConfig.showWidgetMessagePreview,
        widgetPreviewAutoDismissSeconds = settingsConfig.widgetPreviewAutoDismissSeconds,
        widgetPreviewPosition = settingsConfig.widgetPreviewPosition,
        iconMode = settingsConfig.iconMode,
      },
    },
  }
  local settingsPanels = { false, false, false, false, false }
  local result = { settingsPanels = settingsPanels }
  local currentTheme = nil
  local currentOuterWidth = nil

  local function getPanel(index)
    local definition = definitions[index]
    if not definition then
      return nil
    end
    local panel = settingsPanels[index]
    if panel then
      return panel
    end

    local settings
    panel, settings = createSettingsPanel(factory, parent, definition.create, definition.config, onSettingChanged)
    settingsPanels[index] = panel
    result[definition.panelKey] = panel
    result[definition.settingsKey] = settings
    if currentTheme and settings and settings.refreshTheme then
      settings.refreshTheme(currentTheme)
    end
    if currentOuterWidth and settings and settings.refreshLayout then
      local inner = paneInnerWidth(currentOuterWidth)
      if inner then
        settings.refreshLayout(inner)
      end
    end
    if options.onPanelCreated then
      options.onPanelCreated(index, panel, settings)
    end
    return panel
  end
  settingsPanels.getPanel = getPanel

  local function getSettings(index)
    local definition = definitions[index]
    return definition and result[definition.settingsKey] or nil
  end

  local function refreshTheme(theme, context)
    currentTheme = theme
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

    for index = 1, #definitions do
      local settingsView = getSettings(index)
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
    currentOuterWidth = outerWidth
    for index = 1, #definitions do
      local settingsView = getSettings(index)
      if settingsView and settingsView.refreshLayout then
        settingsView.refreshLayout(inner)
      end
    end
  end

  result.getPanel = getPanel
  result.getSettings = getSettings
  result.refreshTheme = refreshTheme
  result.refreshLayout = refreshLayout
  return result
end

ns.MessengerWindowSettingsPanels = SettingsPanels

return SettingsPanels
