local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local RowActions = ns.MessengerWindowRowActions or require("WhisperMessenger.UI.MessengerWindow.RowActions")
local LifecycleSetup = ns.MessengerWindowLifecycleSetup or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LifecycleSetup")
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
local EdgeWiring = ns.MessengerWindowEdgeWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.EdgeWiring")
local SavedStateApply = ns.MessengerWindowSavedStateApply or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SavedStateApply")
local GamepadWiring = ns.MessengerWindowGamepadWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.GamepadWiring")

local MessengerWindow = {}

function MessengerWindow.Create(factory, options)
  options = options or {}

  local shell = WindowShell.Build(factory, options)
  local settingsConfig, compactLayout = shell.settingsConfig, shell.compactLayout
  local initialState, windowGeometry = shell.initialState, shell.windowGeometry
  local chrome, frame, layout = shell.chrome, shell.frame, shell.layout
  local gamepadWiring = GamepadWiring.Create(shell)
  local settingsRuntime = shell.settingsRuntime
  local compactMode = CompactWiring.Hooks()
  local dock = DockWiring.Hooks()
  local edge = EdgeWiring.Hooks()
  local rowActions = RowActions.Collect(options)

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
    rowActions = rowActions,
    getSelectionController = function()
      return selectionController
    end,
    getConversation = function()
      return conversation
    end,
    getSelectedConversationKey = getSelectedConversationKey,
    onNavTargetsChanged = gamepadWiring.refresh,
  })
  local refreshContacts = contactsRuntime.refreshContacts
  local getCurrentContacts = contactsRuntime.getCurrentContacts

  -- Conversation pane
  local conversationWiring = ConversationWiring.Create(factory, {
    threadPane = layout.threadPane,
    windowOptions = options,
    rowActions = rowActions,
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
    onNavTargetsChanged = gamepadWiring.refresh,
  })
  local panelHost = panelWiring.panelHost
  local windowVisibility = panelWiring.windowVisibility
  local setOptionsVisible = windowVisibility.setOptionsVisible

  local composerRuntime = ComposerRuntime.Create(factory, {
    frame = frame,
    layout = layout,
    settingsConfig = settingsConfig,
    windowOptions = options,
    conversation = conversation,
    messageActions = messageActions,
    settingsRuntime = settingsRuntime,
    closeWindow = windowVisibility.closeWindow,
    refreshContacts = refreshContacts,
    onSelectionChanged = function(key)
      compactMode.onSelection(key)
    end,
    onNavTargetsChanged = gamepadWiring.refresh,
  })
  local composer = composerRuntime.composer
  local composerInput = composer.input
  local windowAlpha = composerRuntime.windowAlpha
  selectionController = composerRuntime.selectionController
  local refreshSelection = composerRuntime.refreshSelection

  local wrappedPosition, onResetWindowPosition = CompactWiring.WrapPosition(compactMode, options)
  local onPositionChanged = DockWiring.WrapPosition(dock, EdgeWiring.WrapPosition(edge, wrappedPosition))

  local relayoutWindow, scriptResult = LifecycleSetup.Run(shell, options, {
    composerRuntime = composerRuntime,
    contactsRuntime = contactsRuntime,
    conversation = conversation,
    panelWiring = panelWiring,
    compactMode = compactMode,
    dock = dock,
    edge = edge,
    getSelectedConversationKey = getSelectedConversationKey,
    onResetWindowPosition = onResetWindowPosition,
    onPositionChanged = onPositionChanged,
    getContactsRail = function()
      return contactsRail
    end,
  })
  panelWiring.hookWindowHide()
  gamepadWiring.attach({
    composer = composer,
    conversation = conversation,
    compactMode = compactMode,
    windowVisibility = windowVisibility,
    tabToggle = contactsRuntime.tabToggle,
  })
  EdgeWiring.Attach(edge, {
    factory = factory,
    frame = frame,
    chrome = chrome,
    layout = layout,
    tabToggle = contactsRuntime.tabToggle,
    settingsConfig = settingsConfig,
    compactLayout = compactLayout,
    scriptResult = scriptResult,
  })
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
    windowOptions = EdgeWiring.DockOptions(edge, options),
    windowAlpha = windowAlpha,
    onPositionChanged = onPositionChanged,
    buildState = windowGeometry.buildState,
  })
  EdgeWiring.Bind(edge, dock, applySavedState, windowSizing.relayoutCurrentSize)
  -- One relayout at build, so a bar height reported before the first resize moves the panes.
  windowSizing.relayoutCurrentSize()

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
    applyScreenEdge = edge.applyLive,
  })
end

ns.MessengerWindow = MessengerWindow

return MessengerWindow
