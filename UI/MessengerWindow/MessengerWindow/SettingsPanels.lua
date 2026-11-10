local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SettingsPanelFrame = ns.MessengerWindowSettingsPanelFrame or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanelFrame")

local SettingsPanels = {}

-- Single source of truth for the What's New tab position, so the "?" button
-- and the sidebar tab select the same page without a magic number.
SettingsPanels.PATCH_NOTES_INDEX = 9

function SettingsPanels.Create(factory, options)
  options = options or {}

  local parent = options.parent
  local settingsConfig = options.settingsConfig or {}
  local storeConfig = options.storeConfig or {}
  local onSettingChanged = options.onSettingChanged or function() end
  local patchNotes = options.patchNotes or ns.PatchNotes or {}
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
        hideBattleTagNumbers = settingsConfig.hideBattleTagNumbers,
        showPlayerLevels = settingsConfig.showPlayerLevels,
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
        hudStyle = settingsConfig.hudStyle,
        compactLayout = settingsConfig.compactLayout,
        windowAnimation = settingsConfig.windowAnimation,
        iconDock = settingsConfig.iconDock,
        openAtSavedSpot = settingsConfig.openAtSavedSpot,
      },
    },
    {
      panelKey = "behaviorPanel",
      settingsKey = "behaviorSettings",
      create = options.behaviorCreate,
      viewOptions = { integrations = options.integrations },
      config = {
        dimWhenMoving = settingsConfig.dimWhenMoving,
        autoFocusComposer = settingsConfig.autoFocusComposer,
        deselectComposerOnSend = settingsConfig.deselectComposerOnSend,
        hideOnCombat = settingsConfig.hideOnCombat,
        escapeClosesWindow = settingsConfig.escapeClosesWindow,
        doubleEscapeToClose = settingsConfig.doubleEscapeToClose,
        allowAddonIntegration = settingsConfig.allowAddonIntegration,
        quickReplies = settingsConfig.quickReplies,
      },
    },
    {
      panelKey = "whispersPanel",
      settingsKey = "whispersSettings",
      create = options.whispersCreate,
      config = {
        hideFromDefaultChat = settingsConfig.hideFromDefaultChat,
        closeGameWhisperTab = settingsConfig.closeGameWhisperTab,
        autoOpenIncoming = settingsConfig.autoOpenIncoming,
        autoOpenOutgoing = settingsConfig.autoOpenOutgoing,
        requestsInbox = settingsConfig.requestsInbox,
        shareTypingStatus = settingsConfig.shareTypingStatus,
        shareReadReceipts = settingsConfig.shareReadReceipts,
        showInviteLink = settingsConfig.showInviteLink,
        showWidgetMessagePreview = settingsConfig.showWidgetMessagePreview,
        widgetPreviewReply = settingsConfig.widgetPreviewReply,
        addonGreetings = settingsConfig.addonGreetings,
      },
    },
    {
      panelKey = "chatsPanel",
      settingsKey = "chatsSettings",
      create = options.chatsCreate,
      config = {
        showGroupChats = settingsConfig.showGroupChats,
        enabledChannels = settingsConfig.enabledChannels,
        collapseDuplicates = settingsConfig.collapseDuplicates,
        hideChannelsFromDefaultChat = settingsConfig.hideChannelsFromDefaultChat,
      },
    },
    {
      panelKey = "filtersPanel",
      settingsKey = "filtersSettings",
      create = options.filtersCreate,
      config = {
        filters = options.filters or { ignored = {}, rules = {} },
      },
    },
    {
      panelKey = "notificationsPanel",
      settingsKey = "notificationSettings",
      create = options.notificationCreate,
      config = {
        playSoundOnWhisper = settingsConfig.playSoundOnWhisper,
        notificationSound = settingsConfig.notificationSound,
        flashTaskbarOnWhisper = settingsConfig.flashTaskbarOnWhisper,
        playSoundOnRequest = settingsConfig.playSoundOnRequest,
        requestSound = settingsConfig.requestSound,
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
        iconBackground = settingsConfig.iconBackground,
        iconBorder = settingsConfig.iconBorder,
        iconBorderThemed = settingsConfig.iconBorderThemed,
        widgetShape = settingsConfig.widgetShape,
        widgetStrata = settingsConfig.widgetStrata,
        lockToggleIcon = settingsConfig.lockToggleIcon,
        shareWidgetPosition = settingsConfig.shareWidgetPosition,
        widgetTransparency = settingsConfig.widgetTransparency,
        widgetPreviewAutoDismissSeconds = settingsConfig.widgetPreviewAutoDismissSeconds,
        widgetPreviewPosition = settingsConfig.widgetPreviewPosition,
        iconMode = settingsConfig.iconMode,
      },
    },
    {
      panelKey = "patchNotesPanel",
      settingsKey = "patchNotesSettings",
      create = options.patchNotesCreate,
      config = {
        version = patchNotes.version,
        date = patchNotes.date,
        lines = patchNotes.lines,
      },
    },
  }
  local settingsPanels = { false, false, false, false, false, false, false, false, false }
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
    panel, settings = SettingsPanelFrame.Create(factory, parent, definition.create, definition.config, onSettingChanged, definition.viewOptions)
    settingsPanels[index] = panel
    result[definition.panelKey] = panel
    result[definition.settingsKey] = settings
    if currentTheme and settings and settings.refreshTheme then
      settings.refreshTheme(currentTheme)
    end
    if currentOuterWidth and panel._wmRelayout then
      panel._wmRelayout(currentOuterWidth)
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
    local inner = SettingsPanelFrame.PaneInnerWidth(outerWidth)
    if not inner then
      return
    end
    currentOuterWidth = outerWidth
    for index = 1, #definitions do
      local panel = settingsPanels[index]
      if panel and panel._wmRelayout then
        panel._wmRelayout(outerWidth)
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
