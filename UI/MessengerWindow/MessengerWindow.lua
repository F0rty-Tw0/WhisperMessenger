local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local LifecycleWiring = ns.MessengerWindowLifecycleWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LifecycleWiring")
local WindowShell = ns.MessengerWindowWindowShell or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowShell")
local PanelWiring = ns.MessengerWindowPanelWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PanelWiring")
local ComposerRuntime = ns.MessengerWindowComposerRuntime or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ComposerRuntime")
local PatchNotesRuntime = ns.MessengerWindowPatchNotesRuntime or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PatchNotesRuntime")
local LanguageRefresh = ns.MessengerWindowLanguageRefresh or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LanguageRefresh")
local ContactsRail = ns.MessengerWindowContactsRail or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRail")
local ContactsWiring = ns.MessengerWindowContactsWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsWiring")
local ConversationWiring = ns.MessengerWindowConversationWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ConversationWiring")
local WindowSizing = ns.MessengerWindowWindowSizing or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowSizing")
local WindowSurface = ns.MessengerWindowWindowSurface or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowSurface")
local CompactWiring = ns.MessengerWindowCompactWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.CompactWiring")
local DockWiring = ns.MessengerWindowDockWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.DockWiring")
local SavedStateApply = ns.MessengerWindowSavedStateApply or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SavedStateApply")

local MessengerWindow = {}

function MessengerWindow.Create(factory, options)
  options = options or {}

  local shell = WindowShell.Build(factory, options)
  local settingsConfig, compactLayout = shell.settingsConfig, shell.compactLayout
  local initialState, windowGeometry = shell.initialState, shell.windowGeometry
  local currentContactsWidth = shell.contactsWidth
  local chrome, frame, layout = shell.chrome, shell.frame, shell.layout
  local settingsRuntime = shell.settingsRuntime
  local settingsPanels = settingsRuntime.settingsPanels
  local compactMode = CompactWiring.Hooks()
  local dock = DockWiring.Hooks()

  local function isShown(target)
    if target and target.IsShown then
      return target:IsShown()
    end
    return target ~= nil and target.shown == true
  end

  -- Contacts runtime. The selection controller and conversation pane are
  -- built after it, so its callbacks read these locals at call time.
  local selectionController
  local conversation
  local function getSelectedConversationKey()
    return selectionController and selectionController.getSelectedConversationKey() or nil
  end
  local contactsRuntime = ContactsWiring.Create(factory, {
    layout = layout,
    frame = frame,
    chrome = chrome,
    settingsConfig = settingsConfig,
    windowGeometry = windowGeometry,
    windowOptions = options,
    getSelectionController = function()
      return selectionController
    end,
    getConversation = function()
      return conversation
    end,
    getSelectedConversationKey = getSelectedConversationKey,
  })
  local contactsController = contactsRuntime.contactsController
  local refreshContacts = contactsRuntime.refreshContacts
  local getCurrentContacts = contactsRuntime.getCurrentContacts

  -- Conversation pane
  local conversationWiring = ConversationWiring.Create(factory, {
    threadPane = layout.threadPane,
    windowOptions = options,
    nativeChrome = shell.nativeChrome,
    tabMode = contactsRuntime.getTabMode(),
    settingsConfig = settingsConfig,
  })
  conversation = conversationWiring.conversation
  local messageActions = conversationWiring.messageActions

  local contactsRail -- forward declaration (settings, divider drags and resets drive it)

  local panelWiring = PanelWiring.Create({
    factory = factory,
    frame = frame,
    layout = layout,
    chrome = chrome,
    theme = Theme,
    onClose = options.onClose,
    onPanelShown = options.onPanelShown,
    onConversationUncovered = options.onConversationUncovered,
    onCoverChanged = function(covered)
      compactMode.onCoverChanged(covered)
    end,
    onPanesShown = function()
      compactMode.onPanesShown()
    end,
    getContactsRail = function()
      return contactsRail
    end,
    tabToggle = contactsRuntime.tabToggle,
  })
  local panelHost = panelWiring.panelHost
  local windowVisibility = panelWiring.windowVisibility
  local setOptionsVisible = windowVisibility.setOptionsVisible
  local closeWindow = windowVisibility.closeWindow

  local composerRuntime = ComposerRuntime.Create(factory, {
    frame = frame,
    layout = layout,
    settingsConfig = settingsConfig,
    windowOptions = options,
    conversation = conversation,
    messageActions = messageActions,
    settingsRuntime = settingsRuntime,
    closeWindow = closeWindow,
    refreshContacts = refreshContacts,
    onSelectionChanged = function(key)
      compactMode.onSelection(key)
    end,
  })
  local composer = composerRuntime.composer
  local composerInput = composer.input
  local windowAlpha = composerRuntime.windowAlpha
  local refreshWindowAlpha = windowAlpha.refreshWindowAlpha
  selectionController = composerRuntime.selectionController
  local refreshSelection = composerRuntime.refreshSelection
  local isComposerFocusHeld = composerRuntime.isComposerFocusHeld

  local wrappedPosition, onResetWindowPosition = CompactWiring.WrapPosition(compactMode, options)
  local onPositionChanged = DockWiring.WrapPosition(dock, wrappedPosition)

  local relayoutWindow, scriptResult = LifecycleWiring.Setup({
    layout = layout,
    setContactsWidth = function(nextContactsWidth)
      currentContactsWidth = nextContactsWidth or currentContactsWidth
      windowGeometry.setContactsWidth(currentContactsWidth)
    end,
    composer = composer,
    contactsController = contactsController,
    conversation = conversation,
    refreshContacts = refreshContacts,
    getSelectedConversationKey = getSelectedConversationKey,
    onContactsWidth = panelWiring.onContactsWidth,
    getCurrentContacts = getCurrentContacts,
    selectedContact = options.selectedContact,
    initialConversation = options.conversation,
    initialStatus = options.status,
    refreshSelection = refreshSelection,
    setOptionsVisible = setOptionsVisible,
    chrome = chrome,
    settingsPanels = settingsPanels,
    closeWindow = closeWindow,
    onResetWindowPosition = onResetWindowPosition,
    onWindowMoved = function()
      dock.onWindowMoved()
    end,
    onResetIconPosition = options.onResetIconPosition,
    onClearAllChats = options.onClearAllChats,
    onStartConversation = options.onStartConversation,
    isShown = isShown,
    windowGeometry = windowGeometry,
    frame = frame,
    refreshWindowAlpha = refreshWindowAlpha,
    onPositionChanged = onPositionChanged,
    onBack = function()
      return compactMode.onBack()
    end,
    theme = Theme,
    composerInput = composerInput,
    getAutoFocusChatInput = function()
      return not isComposerFocusHeld() and settingsConfig.autoFocusComposer == true and not compactMode.isListView()
    end,
    getEscapeClosesWindow = function()
      return settingsConfig.escapeClosesWindow ~= false
    end,
    onStrataChanged = function(strata)
      dock.onStrataChanged(strata)
    end,
    isWindowPart = function(candidate)
      return dock.isWindowPart(candidate)
    end,
    isContactsCollapsed = windowGeometry.isCollapsed,
    setContactsCollapsed = function(collapsed, pointerWidth)
      contactsRail.snap(collapsed, pointerWidth)
    end,
    onStateApplied = function(appliedState)
      contactsRail.setCollapsed(appliedState.contactsCollapsed == true)
    end,
  })
  panelWiring.hookWindowHide()
  contactsRail = ContactsRail.Create({
    frame = frame,
    layout = layout,
    windowGeometry = windowGeometry,
    chrome = chrome,
    relayoutWindow = relayoutWindow,
    applyWindowSize = scriptResult.applyWindowSize,
    onPositionChanged = onPositionChanged,
  })

  -- Patch-notes "?" button: glows until the shipped release notes are read.
  PatchNotesRuntime.Attach({
    chrome = chrome,
    layout = layout,
    settingsConfig = settingsConfig,
    setOptionsVisible = setOptionsVisible,
    scriptResult = scriptResult,
  })

  local windowSizing = WindowSizing.Create({
    frame = frame,
    initialState = initialState,
    settingsConfig = settingsConfig,
    chrome = chrome,
    windowGeometry = windowGeometry,
    scriptResult = scriptResult,
    relayoutWindow = relayoutWindow,
  })

  local applySavedState, applyPending = SavedStateApply.Create({
    compactLayout = compactLayout,
    compactMode = compactMode,
    dock = dock,
    scriptResult = scriptResult,
  })

  -- Compact first: its hide finishes a slide before the dock's hide closes.
  if compactLayout then
    CompactWiring.Attach(compactMode, {
      frame = frame,
      layout = layout,
      chrome = chrome,
      tabToggle = contactsRuntime.tabToggle,
      composerInput = composerInput,
      windowVisibility = windowVisibility,
      windowOptions = options,
      settingsConfig = settingsConfig,
      getSelectedKey = getSelectedConversationKey,
      refreshSelection = refreshSelection,
      applyWindowSize = scriptResult.applyWindowSize,
      applyPending = applyPending,
    })
  end
  DockWiring.Attach(frame, {
    hooks = dock,
    factory = factory,
    chrome = chrome,
    windowOptions = options,
    windowAlpha = windowAlpha,
    onPositionChanged = onPositionChanged,
    buildState = windowGeometry.buildState,
  })

  local refreshLanguage = LanguageRefresh.Create({
    layout = layout,
    composer = composer,
    settingsRuntime = settingsRuntime,
    settingsConfig = settingsConfig,
    contactsRuntime = contactsRuntime,
    relayoutCurrentSize = windowSizing.relayoutCurrentSize,
    conversation = conversation,
    scriptResult = scriptResult,
    refreshContacts = refreshContacts,
    getCurrentContacts = getCurrentContacts,
    selectionController = selectionController,
  })

  return WindowSurface.Build({
    chrome = chrome,
    layout = layout,
    settingsRuntime = settingsRuntime,
    settingsResult = shell.settingsResult,
    contactsRuntime = contactsRuntime,
    conversation = conversation,
    composer = composer,
    refreshSelection = refreshSelection,
    handleContactSelected = selectionController.handleContactSelected,
    setScale = function(nextScale)
      local scale = windowSizing.setScale(nextScale)
      dock.dock()
      return scale
    end,
    relayoutCurrentSize = windowSizing.relayoutCurrentSize,
    refreshLanguage = refreshLanguage,
    panelHost = panelHost,
    windowVisibility = windowVisibility,
    showWithoutComposerFocus = composerRuntime.showWithoutComposerFocus,
    refreshEscapeSetting = scriptResult.refreshEscape,
    compactMode = compactLayout and compactMode or nil,
    dock = dock.dock,
    applySavedState = applySavedState,
  })
end

ns.MessengerWindow = MessengerWindow

return MessengerWindow
