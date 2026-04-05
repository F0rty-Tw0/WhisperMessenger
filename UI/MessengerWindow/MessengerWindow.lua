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
local FacadeBuilder = ns.MessengerWindowFacadeBuilder
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.FacadeBuilder")
local FacadePayload = ns.MessengerWindowFacadePayload
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.FacadePayload")
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

  -- Build chrome (outer frame, buttons, etc.)
  local chrome = ChromeBuilder.Build(factory, parent, initialState, { title = options.title })
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
  local contactsRuntime = ContactsRuntime.Create(factory, {
    contactsView = contactsView,
    initialContacts = options.contacts or {},
    settingsConfig = settingsConfig,
    onSelect = function(item)
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
  end, closeWindow)
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

  local function refreshSelection(nextState, resetPaging)
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

  return FacadeBuilder.Build(FacadePayload.Build({
    chrome = chrome,
    layout = layout,
    settings = {
      general = generalSettings,
      appearance = appearanceSettings,
      behavior = behaviorSettings,
      notifications = notificationSettings,
    },
    contacts = contacts,
    conversation = conversation,
    composer = composer,
    refreshContacts = refreshContacts,
    refreshSelection = refreshSelection,
    refreshTheme = refreshThemeVisuals,
    handleContactSelected = handleContactSelected,
  }))
end

ns.MessengerWindow = MessengerWindow

return MessengerWindow
