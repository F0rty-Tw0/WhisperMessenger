local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local Composer = ns.Composer or require("WhisperMessenger.UI.Composer")
local AlphaController = ns.MessengerWindowAlphaController or require("WhisperMessenger.UI.MessengerWindow.AlphaController")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local ChromeBuilder = ns.MessengerWindowChromeBuilder or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local WindowScripts = ns.MessengerWindowWindowScripts or require("WhisperMessenger.UI.MessengerWindow.WindowScripts")
local ContactsRuntime = ns.MessengerWindowContactsRuntime or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")
local TabSelectionMemory = ns.MessengerWindowTabSelectionMemory or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.TabSelectionMemory")
local SettingsPanelsBootstrap = ns.MessengerWindowSettingsPanelsBootstrap
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanelsBootstrap")
local SelectionSync = ns.MessengerWindowSelectionSync or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionSync")
local SelectionController = ns.MessengerWindowSelectionController
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionController")
local WindowVisibility = ns.MessengerWindowWindowVisibility or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowVisibility")
local WindowAlpha = ns.MessengerWindowWindowAlpha or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowAlpha")
local WindowGeometry = ns.MessengerWindowWindowGeometry or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGeometry")
local ScriptWiring = ns.MessengerWindowScriptWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ScriptWiring")
local RelayoutController = ns.MessengerWindowRelayoutController or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.RelayoutController")
local LifecycleWiring = ns.MessengerWindowLifecycleWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LifecycleWiring")
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
  local optionsScrollContent = layout.optionsScrollView and layout.optionsScrollView.content or layout.optionsContentPane
  local contactsView = layout.contactsView
  local contactsSearchInput = layout.contactsSearchInput
  local contactsSearchClearButton = layout.contactsSearchClearButton
  local contactsSearchPlaceholder = layout.contactsSearchPlaceholder
  -- Compose settings panels (each inside its own frame within optionsContentPane)
  local settingsRuntime = SettingsPanelsBootstrap.Create(factory, {
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
  -- Per-tab remembered selection/restore policy. Keep it in a focused helper
  -- so Create only wires runtime dependencies instead of owning the policy.
  local refreshSelection -- forward declaration (used by swap callback below)
  -- IMPORTANT: declare before the `= Create(...)` call so the callbacks
  -- inside the table constructor capture THIS local (not a global/nil).
  -- Lua local scope begins AFTER the declaration statement completes.
  local contactsRuntime
  local tabSelectionMemory = TabSelectionMemory.Create({
    getSelectedConversationKey = function()
      return selectionController and selectionController.getSelectedConversationKey() or nil
    end,
    getCurrentContacts = function()
      if contactsRuntime and contactsRuntime.getCurrentContacts then
        return contactsRuntime.getCurrentContacts() or {}
      end
      return {}
    end,
    handleContactSelected = function(item)
      if handleContactSelected then
        handleContactSelected(item)
      end
    end,
    refreshSelection = function(nextState)
      if refreshSelection then
        refreshSelection(nextState)
      end
    end,
  })
  contactsRuntime = ContactsRuntime.Create(factory, {
    contactsPane = contactsPane,
    contactsView = contactsView,
    initialContacts = options.contacts or {},
    settingsConfig = settingsConfig,
    initialTabMode = options.initialTabMode,
    onTabModeChanged = options.onTabModeChanged,
    onTabModeSwapSelection = tabSelectionMemory.onTabModeSwapSelection,
    onSelect = tabSelectionMemory.onSelect,
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
    setComposerEnabled = function(selectedContact, noticeText, status)
      SelectionSync.SetComposerEnabled(composer, selectedContact, noticeText, status)
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

  local _relayoutWindow, scriptResult = LifecycleWiring.Setup({
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

  local function refreshLanguage(lang)
    -- GeneralSettings.applyLanguage uses `nextLanguage or DEFAULTS.interfaceLanguage`,
    -- so calling it with nil silently resets the panel to "auto" and unselects
    -- the user's choice in the language selector. Resolve the live setting
    -- when the caller doesn't pass an explicit language.
    local effectiveLang = lang or settingsConfig.interfaceLanguage
    -- Each child widget owns the labels it created and re-resolves them from
    -- the active Localization catalog. Call them in dependency order so a
    -- StatusLine.Build() that runs during the contacts refresh sees fresh
    -- catalog state.
    if layout.setLanguage then
      layout.setLanguage()
    end
    if composer.setLanguage then
      composer.setLanguage()
    end
    if generalSettings and generalSettings.setLanguage then
      generalSettings.setLanguage(effectiveLang)
    end
    if appearanceSettings and appearanceSettings.setLanguage then
      appearanceSettings.setLanguage()
    end
    if behaviorSettings and behaviorSettings.setLanguage then
      behaviorSettings.setLanguage()
    end
    if notificationSettings and notificationSettings.setLanguage then
      notificationSettings.setLanguage()
    end
    if contactsRuntime and contactsRuntime.tabToggle and contactsRuntime.tabToggle.setLanguage then
      contactsRuntime.tabToggle.setLanguage()
    end
    if conversation then
      ConversationPane.SetLanguage(conversation)
    end
    if scriptResult and scriptResult.setLanguage then
      scriptResult.setLanguage()
    end
    -- Force a contacts refresh so dynamic labels (group channel labels,
    -- the "no group chats yet" empty state, contact preview timestamps)
    -- pick up the new locale.
    if refreshContacts then
      refreshContacts(getCurrentContacts(), selectionController and selectionController.getSelectedConversationKey() or nil, false)
    end
  end

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
    refreshLanguage = refreshLanguage,
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
