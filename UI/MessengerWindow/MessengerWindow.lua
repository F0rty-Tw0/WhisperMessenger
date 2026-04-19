local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local Composer = ns.Composer or require("WhisperMessenger.UI.Composer")
local AlphaController = ns.MessengerWindowAlphaController
  or require("WhisperMessenger.UI.MessengerWindow.AlphaController")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local ChromeBuilder = ns.MessengerWindowChromeBuilder or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local WindowScripts = ns.MessengerWindowWindowScripts or require("WhisperMessenger.UI.MessengerWindow.WindowScripts")
local ContactsRuntime = ns.MessengerWindowContactsRuntime
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")
local SettingsRuntime = ns.MessengerWindowSettingsRuntime
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsRuntime")
local SelectionSync = ns.MessengerWindowSelectionSync
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionSync")
local SelectionController = ns.MessengerWindowSelectionController
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionController")
local WindowVisibility = ns.MessengerWindowWindowVisibility
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowVisibility")
local WindowAlpha = ns.MessengerWindowWindowAlpha
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowAlpha")
local WindowGeometry = ns.MessengerWindowWindowGeometry
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGeometry")
local ScriptWiring = ns.MessengerWindowScriptWiring
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ScriptWiring")
local RelayoutController = ns.MessengerWindowRelayoutController
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.RelayoutController")
local LifecycleWiring = ns.MessengerWindowLifecycleWiring
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LifecycleWiring")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local trace = ns.trace or require("WhisperMessenger.Core.Trace")
local sizeValue = UIHelpers.sizeValue
local captureFramePosition = UIHelpers.captureFramePosition

local MessengerWindow = {}

function MessengerWindow.Create(factory, options)
  options = options or {}

  local parent = options.parent or _G.UIParent
  local state = options.state or {}
  local initialState = WindowBounds.ClampState(parent, {
    anchorPoint = state.anchorPoint or "CENTER",
    relativePoint = state.relativePoint or state.anchorPoint or "CENTER",
    x = state.x or 0,
    y = state.y or 0,
    width = state.width or Theme.WINDOW_WIDTH,
    height = state.height or Theme.WINDOW_HEIGHT,
    minimized = state.minimized or false,
  }, Theme)
  local windowGeometry = WindowGeometry.Create({
    parent = parent,
    theme = Theme,
    clampState = WindowBounds.ClampState,
    clampContactsWidth = LayoutBuilder.ClampContactsWidth,
    captureFramePosition = captureFramePosition,
    sizeValue = sizeValue,
    initialState = initialState,
    initialContactsWidth = state.contactsWidth,
  })
  local currentContactsWidth = windowGeometry.getContactsWidth()

  local function isShown(target)
    if target and target.IsShown then
      return target:IsShown()
    end
    return target ~= nil and target.shown == true
  end

  -- Build chrome (outer frame, buttons, etc.). useNativeChrome flips
  -- the frame to BasicFrameTemplateWithInset (gold border, red X) — read
  -- from saved settings so it persists across reloads.
  local chrome = ChromeBuilder.Build(factory, parent, initialState, {
    title = options.title,
    useNativeChrome = options.settingsConfig and options.settingsConfig.nativeChrome == true,
  })
  local frame = chrome.frame
  -- Settings config (must be available before layout and alpha wiring)
  local settingsConfig = options.settingsConfig or {}

  -- Build layout (panes)
  local layout = LayoutBuilder.Build(factory, frame, initialState, { contactsWidth = currentContactsWidth })
  currentContactsWidth = layout.contactsWidth or currentContactsWidth
  windowGeometry.setContactsWidth(currentContactsWidth)
  local contactsPane = layout.contactsPane
  local contentPane = layout.contentPane
  local threadPane = layout.threadPane
  local composerPane = layout.composerPane
  local optionsPanel = layout.optionsPanel
  local optionsScrollContent = layout.optionsScrollView and layout.optionsScrollView.content
    or layout.optionsContentPane
  local contactsView = layout.contactsView
  local contactsSearchInput = layout.contactsSearchInput
  local contactsSearchClearButton = layout.contactsSearchClearButton
  local contactsSearchPlaceholder = layout.contactsSearchPlaceholder
  -- Compose settings panels (each inside its own frame within optionsContentPane)
  local settingsRuntime = SettingsRuntime.Create(factory, {
    parent = optionsScrollContent,
    settingsConfig = settingsConfig,
    storeConfig = options.storeConfig or {},
    onSettingChanged = options.onSettingChanged,
    theme = Theme,
    chrome = chrome,
    layout = layout,
  })
  local generalPanel = settingsRuntime.generalPanel
  local generalSettings = settingsRuntime.generalSettings
  local appearancePanel = settingsRuntime.appearancePanel
  local appearanceSettings = settingsRuntime.appearanceSettings
  local behaviorPanel = settingsRuntime.behaviorPanel
  local behaviorSettings = settingsRuntime.behaviorSettings
  local notificationsPanel = settingsRuntime.notificationsPanel
  local notificationSettings = settingsRuntime.notificationSettings
  local refreshThemeVisuals = settingsRuntime.refreshThemeVisuals

  -- Contacts controller (manages rows, paging, scroll hooks)
  local handleContactSelected -- forward declaration
  local selectionController = nil
  -- Per-tab remembered selection. Each tab remembers its last-selected
  -- conversation key; switching tabs restores it (or clears when empty).
  local tabSelections = { whispers = nil, groups = nil }
  local refreshSelection -- forward declaration (used by swap callback below)
  -- IMPORTANT: declare before the `= Create(...)` call so the callbacks
  -- inside the table constructor capture THIS local (not a global/nil).
  -- Lua local scope begins AFTER the declaration statement completes.
  local contactsRuntime
  contactsRuntime = ContactsRuntime.Create(factory, {
    contactsPane = contactsPane,
    contactsView = contactsView,
    initialContacts = options.contacts or {},
    settingsConfig = settingsConfig,
    initialTabMode = options.initialTabMode,
    onTabModeChanged = options.onTabModeChanged,
    onTabModeSwapSelection = function(oldMode, newMode)
      -- Save the selection that was active in the old tab as a safety net —
      -- onSelect below tracks this eagerly, but a snapshot here catches the
      -- first tab switch in a session where onSelect may not have fired yet.
      if selectionController then
        local liveKey = selectionController.getSelectedConversationKey()
        if liveKey ~= nil then
          tabSelections[oldMode] = liveKey
        end
      end
      -- Restore the new tab's remembered selection (or clear). Look up the
      -- full contact from getCurrentContacts() rather than the virtualized
      -- row set — the remembered selection may be off-screen (below the
      -- visible-row window) and wouldn't otherwise be findable.
      local nextKey = tabSelections[newMode]
      local matched = false
      if nextKey and contactsRuntime and contactsRuntime.getCurrentContacts then
        for _, item in ipairs(contactsRuntime.getCurrentContacts() or {}) do
          if item ~= nil and item.conversationKey == nextKey then
            if handleContactSelected then
              handleContactSelected(item)
            end
            matched = true
            break
          end
        end
      end
      if not matched and refreshSelection then
        refreshSelection({})
      end
    end,
    onSelect = function(item)
      -- Remember the selection per-tab so tab switches can restore it.
      -- Tracked on every select (not just tab switch) so the memory stays
      -- fresh even when the user clicks a different conversation within
      -- the same tab before switching.
      if item and item.conversationKey and contactsRuntime and contactsRuntime.getTabMode then
        local mode = contactsRuntime.getTabMode()
        if mode == "whispers" or mode == "groups" then
          tabSelections[mode] = item.conversationKey
        end
      end
      if handleContactSelected then
        handleContactSelected(item)
      end
    end,
    onPin = options.onPin,
    onRemove = options.onRemove,
    onReorder = options.onReorder,
    contactsSearchInput = contactsSearchInput,
    contactsSearchClearButton = contactsSearchClearButton,
    contactsSearchPlaceholder = contactsSearchPlaceholder,
    getSelectedConversationKey = function()
      return selectionController and selectionController.getSelectedConversationKey() or nil
    end,
  })
  local contactsController = contactsRuntime.contactsController
  local contacts = contactsRuntime.contacts
  local refreshContacts = contactsRuntime.refreshContacts
  local getCurrentContacts = contactsRuntime.getCurrentContacts
  contactsRuntime.bindInputScripts()

  -- Conversation pane
  local conversation = ConversationPane.Create(factory, threadPane, options.selectedContact, options.conversation)

  -- Composer (created before wiring alpha so we have composer.input)
  local composerSelectedContact = {}

  local windowVisibility = WindowVisibility.Create({
    optionsPanel = optionsPanel,
    contactsPane = contactsPane,
    contentPane = contentPane,
    frame = frame,
    onClose = options.onClose,
    trace = trace,
  })
  local setOptionsVisible = windowVisibility.setOptionsVisible
  local closeWindow = windowVisibility.closeWindow

  local composer = Composer.Create(factory, composerPane, composerSelectedContact, options.onSend or function(...)
    local _ = ...
  end, closeWindow, function()
    return settingsConfig.doubleEscapeToClose == true
  end)
  settingsRuntime.setThemeTargets(conversation, composer)

  -- Alpha helpers (capture composer.input now that composer exists)
  local composerInput = composer.input
  local windowAlpha = WindowAlpha.Create({
    alphaController = AlphaController,
    frame = frame,
    composerInput = composerInput,
    settingsConfig = settingsConfig,
  })
  local refreshWindowAlpha = windowAlpha.refreshWindowAlpha

  -- Selection management
  selectionController = SelectionController.Create({
    refreshContacts = refreshContacts,
    refreshConversationPane = function(selectedContact, selectedConversation, selectedStatus, noticeText)
      ConversationPane.Refresh(conversation, selectedContact, selectedConversation, selectedStatus, noticeText)
    end,
    syncComposerSelectedContact = function(selectedContact)
      SelectionSync.SyncComposerSelectedContact(composerSelectedContact, selectedContact)
    end,
    setComposerEnabled = function(selectedContact, noticeText)
      SelectionSync.SetComposerEnabled(composer, selectedContact, noticeText)
    end,
    onSelectConversation = options.onSelectConversation,
    getSelectedContact = options.getSelectedContact,
    getConversation = options.getConversation,
    getStatus = options.getStatus,
  })

  refreshSelection = function(nextState, resetPaging)
    selectionController.refresh(nextState, resetPaging)
  end

  handleContactSelected = selectionController.handleContactSelected

  LifecycleWiring.Setup({
    relayoutFactory = RelayoutController,
    layoutBuilder = LayoutBuilder,
    layout = layout,
    setContactsWidth = function(nextContactsWidth)
      currentContactsWidth = nextContactsWidth or currentContactsWidth
      windowGeometry.setContactsWidth(currentContactsWidth)
    end,
    composer = composer,
    contactsController = contactsController,
    conversation = conversation,
    conversationPane = ConversationPane,
    refreshContacts = refreshContacts,
    getSelectedConversationKey = function()
      return selectionController and selectionController.getSelectedConversationKey() or nil
    end,
    getCurrentContacts = getCurrentContacts,
    selectedContact = options.selectedContact,
    initialConversation = options.conversation,
    initialStatus = options.status,
    refreshSelection = refreshSelection,
    setOptionsVisible = setOptionsVisible,
    scriptWiring = ScriptWiring,
    windowScripts = WindowScripts,
    chrome = chrome,
    settingsPanels = { generalPanel, appearancePanel, behaviorPanel, notificationsPanel },
    closeWindow = closeWindow,
    onResetWindowPosition = options.onResetWindowPosition,
    onResetIconPosition = options.onResetIconPosition,
    onClearAllChats = options.onClearAllChats,
    onStartConversation = options.onStartConversation,
    isShown = isShown,
    windowGeometry = windowGeometry,
    frame = frame,
    refreshWindowAlpha = refreshWindowAlpha,
    trace = trace,
    onPositionChanged = options.onPositionChanged,
    theme = Theme,
    composerInput = composerInput,
    getAutoFocusChatInput = function()
      return settingsConfig.autoFocusComposer == true
    end,
  })

  trace("window created", initialState.anchorPoint, initialState.x, initialState.y)

  return {
    frame = chrome.frame,
    title = chrome.title,
    newConversationButton = chrome.newConversationButton,
    contactsPane = layout.contactsPane,
    contactsPaneBorder = layout.contactsPaneBorder,
    contactsDivider = layout.contactsDivider,
    contactsRightBorder = layout.contactsRightBorder,
    contactsHeaderDivider = layout.contactsHeaderDivider,
    contentPane = layout.contentPane,
    headerDivider = layout.headerDivider,
    titleBarBorder = chrome.titleBarBorder,
    titleBarTopBorder = chrome.titleBarTopBorder,
    threadPane = layout.threadPane,
    composerPane = layout.composerPane,
    composerPaneBorder = layout.composerPaneBorder,
    composerDivider = layout.composerDivider,
    closeButton = chrome.closeButton,
    optionsButton = chrome.optionsButton,
    optionsPanel = layout.optionsPanel,
    optionsMenu = layout.optionsMenu,
    optionsContentPane = layout.optionsContentPane,
    generalTab = layout.generalTab,
    appearanceTab = layout.appearanceTab,
    behaviorTab = layout.behaviorTab,
    notificationsTab = layout.notificationsTab,
    generalSettings = generalSettings,
    appearanceSettings = appearanceSettings,
    behaviorSettings = behaviorSettings,
    notificationSettings = notificationSettings,
    optionsHeader = layout.optionsHeader,
    optionsHint = layout.optionsHint,
    resetWindowButton = layout.resetWindowButton,
    resetIconButton = layout.resetIconButton,
    clearAllChatsButton = layout.clearAllChatsButton,
    contactsSearchInput = layout.contactsSearchInput,
    contactsSearchClearButton = layout.contactsSearchClearButton,
    contactsSearchPlaceholder = layout.contactsSearchPlaceholder,
    resizeGrip = chrome.resizeGrip,
    contactsResizeHandle = layout.contactsResizeHandle,
    contacts = contacts,
    conversation = conversation,
    composer = composer,
    refreshContacts = refreshContacts,
    refreshSelection = refreshSelection,
    refreshTheme = refreshThemeVisuals,
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
end

ns.MessengerWindow = MessengerWindow

return MessengerWindow
