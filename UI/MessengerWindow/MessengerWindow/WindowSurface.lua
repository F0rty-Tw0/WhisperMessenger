local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SettingsPanels = ns.MessengerWindowSettingsPanels or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")

local WindowSurface = {}

-- Window field name per settings panel index.
local SETTING_KEYS = {
  "generalSettings",
  "appearanceSettings",
  "behaviorSettings",
  "whispersSettings",
  "chatsSettings",
  "filtersSettings",
  "notificationSettings",
  "iconSettings",
  "patchNotesSettings",
}

-- Settings panels are built when their tab is first selected. Returns the
-- table that collects them by window field name, and the SettingsRuntime
-- onPanelCreated callback that fills it.
function WindowSurface.CollectSettings()
  local settingsResult = {}
  return settingsResult, function(index, _panel, settings)
    settingsResult[SETTING_KEYS[index]] = settings
  end
end

-- Addon panel entry points: registerPanel, showPanel, hidePanel(quiet),
-- setOptionsVisible(visible, quiet), getVisiblePanel, refreshPanelBadge, and
-- isConversationPaneShown (false while a panel or the options pane covers the
-- chat). quiet closes without reporting the chat uncovered, for callers that
-- select a chat themselves right after.
local function addPanelFields(window, panelHost, windowVisibility)
  window.registerPanel = panelHost.register
  window.showPanel = windowVisibility.setPanelVisible
  window.hidePanel = function(quiet)
    windowVisibility.setPanelVisible(nil, quiet)
  end
  window.setOptionsVisible = windowVisibility.setOptionsVisible
  window.getVisiblePanel = windowVisibility.getVisiblePanel
  window.isConversationPaneShown = windowVisibility.isConversationPaneShown
  window.refreshPanelBadge = panelHost.refreshBadge
end

-- Builds the table MessengerWindow.Create returns. Fields it does not list
-- fall back to settingsResult (lazily built settings panels).
-- parts: chrome, layout, settingsRuntime, settingsResult, contactsRuntime,
-- conversation, composer, refreshSelection, handleContactSelected, setScale,
-- relayoutCurrentSize, refreshLanguage, and optionally panelHost +
-- windowVisibility (addon panels).
function WindowSurface.Build(parts)
  local chrome = parts.chrome
  local layout = parts.layout
  local settingsRuntime = parts.settingsRuntime
  local contactsRuntime = parts.contactsRuntime
  local contacts = contactsRuntime.contacts
  local refreshSelection = parts.refreshSelection
  local handleContactSelected = parts.handleContactSelected
  local relayoutCurrentSize = parts.relayoutCurrentSize
  local refreshThemeVisuals = settingsRuntime.refreshThemeVisuals

  local window = {
    frame = chrome.frame,
    title = chrome.title,
    newConversationButton = chrome.newConversationButton,
    markAllReadButton = chrome.markAllReadButton,
    patchNotesButton = chrome.patchNotesButton,
    contactsPane = layout.contactsPane,
    contactsDivider = layout.contactsDivider,
    contentPane = layout.contentPane,
    headerDivider = layout.headerDivider,
    threadPane = layout.threadPane,
    composerPane = layout.composerPane,
    closeButton = chrome.closeButton,
    optionsButton = chrome.optionsButton,
    backButton = chrome.backButton,
    optionsPanel = layout.optionsPanel,
    optionsMenu = layout.optionsMenu,
    optionsContentPane = layout.optionsContentPane,
    generalTab = layout.generalTab,
    appearanceTab = layout.appearanceTab,
    behaviorTab = layout.behaviorTab,
    whispersTab = layout.whispersTab,
    chatsTab = layout.chatsTab,
    filtersTab = layout.filtersTab,
    notificationsTab = layout.notificationsTab,
    iconsTab = layout.iconsTab,
    whatsNewTab = layout.whatsNewTab,
    settingsPanels = settingsRuntime.settingsPanels,
    generalSettings = settingsRuntime.getSettings(1),
    appearanceSettings = settingsRuntime.getSettings(2),
    behaviorSettings = settingsRuntime.getSettings(3),
    notificationSettings = settingsRuntime.getSettings(7),
    iconSettings = settingsRuntime.getSettings(8),
    patchNotesSettings = settingsRuntime.getSettings(SettingsPanels.PATCH_NOTES_INDEX),
    optionsHint = layout.optionsHint,
    resetWindowButton = layout.resetWindowButton,
    resetIconButton = layout.resetIconButton,
    clearAllChatsButton = layout.clearAllChatsButton,
    contactsSearchInput = layout.contactsSearchInput,
    contactsSearchClearButton = layout.contactsSearchClearButton,
    contactsSearchPlaceholder = layout.contactsSearchPlaceholder,
    contactsRailSearchButton = layout.contactsRailSearchButton,
    resizeGrip = chrome.resizeGrip,
    contactsResizeHandle = layout.contactsResizeHandle,
    tabToggle = contactsRuntime.tabToggle,
    contacts = contacts,
    conversation = parts.conversation,
    composer = parts.composer,
    refreshContacts = contactsRuntime.refreshContacts,
    refreshSelection = refreshSelection,
    refreshTheme = function()
      refreshThemeVisuals()
      -- Tab bar reads colours at paint time; re-set the current mode to
      -- repaint it without firing the mode-change callback.
      local tabToggle = contactsRuntime.tabToggle
      if tabToggle then
        tabToggle.setMode(tabToggle.getMode())
      end
      -- Re-apply pane anchors and composer geometry for the new theme.
      relayoutCurrentSize()
    end,
    setScale = parts.setScale,
    refreshLanguage = parts.refreshLanguage,
    refreshTabToggleVisibility = contactsRuntime.refreshTabToggleVisibility,
    setTabMode = contactsRuntime.setTabMode,
    getTabMode = contactsRuntime.getTabMode,
    selectConversation = function(conversationKey)
      for _, row in ipairs(contacts.rows) do
        if row.item ~= nil and row.item.conversationKey == conversationKey then
          handleContactSelected(row.item)
          return true
        end
      end
      refreshSelection()
      return false
    end,
  }
  if parts.panelHost and parts.windowVisibility then
    addPanelFields(window, parts.panelHost, parts.windowVisibility)
  end
  return setmetatable(window, { __index = parts.settingsResult })
end

ns.MessengerWindowWindowSurface = WindowSurface

return WindowSurface
