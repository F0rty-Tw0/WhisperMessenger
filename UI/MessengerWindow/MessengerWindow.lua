local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local Composer = ns.Composer or require("WhisperMessenger.UI.Composer")
local AlphaController = ns.MessengerWindowAlphaController or require("WhisperMessenger.UI.MessengerWindow.AlphaController")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local WindowScale = ns.MessengerWindowWindowScale or require("WhisperMessenger.UI.MessengerWindow.WindowScale")
local ChromeBuilder = ns.MessengerWindowChromeBuilder or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local SettingsRuntime = ns.MessengerWindowSettingsRuntime or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsRuntime")
local SelectionSync = ns.MessengerWindowSelectionSync or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionSync")
local SelectionController = ns.MessengerWindowSelectionController
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionController")
local PanelWiring = ns.MessengerWindowPanelWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PanelWiring")
local WindowAlpha = ns.MessengerWindowWindowAlpha or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowAlpha")
local WindowGeometry = ns.MessengerWindowWindowGeometry or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGeometry")
local LifecycleWiring = ns.MessengerWindowLifecycleWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LifecycleWiring")
local PatchNotesRuntime = ns.MessengerWindowPatchNotesRuntime or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PatchNotesRuntime")
local LanguageRefresh = ns.MessengerWindowLanguageRefresh or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LanguageRefresh")
local ContactsRail = ns.MessengerWindowContactsRail or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRail")
local ContactsWiring = ns.MessengerWindowContactsWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsWiring")
local ConversationWiring = ns.MessengerWindowConversationWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ConversationWiring")
local WindowSizing = ns.MessengerWindowWindowSizing or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowSizing")
local WindowSurface = ns.MessengerWindowWindowSurface or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowSurface")
local PhoneWiring = ns.MessengerWindowPhoneWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneWiring")
local PhoneDock = ns.MessengerWindowPhoneDock or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDock")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local StyledTextInputPopup = ns.StyledTextInputPopup or require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
local sizeValue = UIHelpers.sizeValue
local captureFramePosition = UIHelpers.captureFramePosition

local MessengerWindow = {}

function MessengerWindow.Create(factory, options)
  options = options or {}

  local parent = options.parent or _G.UIParent
  local settingsConfig = options.settingsConfig or {}
  local initialScale = WindowScale.Normalize(settingsConfig.windowScale)
  settingsConfig.windowScale = initialScale
  local state = options.state or {}
  local phoneLayout = options.phoneLayout == true
  local phone = PhoneWiring.Hooks()
  local initialState = WindowSizing.InitialState(parent, state, initialScale, phoneLayout)
  local windowGeometry = WindowGeometry.Create({
    parent = parent,
    theme = Theme,
    clampState = WindowBounds.ClampState,
    clampContactsWidth = LayoutBuilder.ClampContactsWidth,
    captureFramePosition = phoneLayout and PhoneDock.CapturePosition or captureFramePosition,
    sizeValue = sizeValue,
    initialState = initialState,
    initialContactsWidth = state.contactsWidth,
    initialScale = initialScale,
  })
  local currentContactsWidth = windowGeometry.getContactsWidth()

  local function isShown(target)
    if target and target.IsShown then
      return target:IsShown()
    end
    return target ~= nil and target.shown == true
  end

  -- Build chrome (outer frame, buttons, etc.). useNativeChrome flips the
  -- frame to the HUD style's Blizzard template (see ChromeBuilder), set at
  -- boot, so a change applies after /reload.
  local nativeChrome = Hud.IsOn()
  StyledTextInputPopup.nativeChrome = nativeChrome
  local chrome = ChromeBuilder.Build(factory, parent, initialState, {
    title = options.title,
    useNativeChrome = nativeChrome,
    windowScale = initialScale,
    onMarkAllRead = options.onMarkAllRead,
    phoneLayout = phoneLayout,
  })
  local frame = chrome.frame

  -- Build layout (panes)
  local layout = LayoutBuilder.Build(factory, frame, initialState, { contactsWidth = currentContactsWidth, phoneLayout = phoneLayout })
  currentContactsWidth = layout.expandedContactsWidth or layout.contactsWidth or currentContactsWidth
  windowGeometry.setContactsWidth(currentContactsWidth)
  local optionsScrollContent = layout.optionsScrollView and layout.optionsScrollView.content or layout.optionsContentPane
  -- Construct each settings panel when its tab is selected.
  local settingsResult, onPanelCreated = WindowSurface.CollectSettings()
  local settingsRuntime = SettingsRuntime.Create(factory, {
    parent = optionsScrollContent,
    settingsConfig = settingsConfig,
    storeConfig = options.storeConfig or {},
    filters = options.filters,
    onSettingChanged = options.onSettingChanged,
    theme = Theme,
    chrome = chrome,
    layout = layout,
    onPanelCreated = onPanelCreated,
  })
  local settingsPanels = settingsRuntime.settingsPanels

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
    nativeChrome = nativeChrome,
    tabMode = contactsRuntime.getTabMode(),
  })
  conversation = conversationWiring.conversation
  local messageActions = conversationWiring.messageActions

  -- Composer (created before wiring alpha so we have composer.input)
  local contactsRail -- forward declaration (settings, divider drags and resets drive it)
  local composerSelectedContact = {}

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
      phone.onCoverChanged(covered)
    end,
    onPanesShown = function()
      phone.onPanesShown()
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

  local composerOptions = {
    nativeChrome = layout.nativeChrome == true,
    onDraftChanged = options.onDraftChanged,
    onReplyChanged = messageActions.onReplyChanged,
    getQuickReplies = function()
      return settingsConfig.quickReplies
    end,
    getDeselectOnSend = function()
      return settingsConfig.deselectComposerOnSend == true
    end,
  }
  local composer = Composer.Create(factory, layout.composerPane, composerSelectedContact, options.onSend or function(...)
    local _ = ...
  end, closeWindow, function()
    return settingsConfig.doubleEscapeToClose == true
  end, options.onTyping, composerOptions)
  settingsRuntime.setThemeTargets(conversation, composer)
  messageActions.bind(conversation, composer)

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
      SelectionSync.SyncComposerSelectedContact(composerSelectedContact, selectedContact, composer, options.getDraft)
    end,
    setComposerEnabled = function(selectedContact, noticeText)
      SelectionSync.SetComposerEnabled(composer, selectedContact, noticeText)
    end,
    onSelectConversation = options.onSelectConversation,
    onSelectionChanged = function(key)
      phone.onSelection(key)
    end,
    getSelectedContact = options.getSelectedContact,
    getConversation = options.getConversation,
    getStatus = options.getStatus,
  })

  local function refreshSelection(nextState, resetPaging)
    selectionController.refresh(nextState, resetPaging)
  end

  local handleContactSelected = selectionController.handleContactSelected

  -- OnShow focuses the composer when the setting is on; an open the player
  -- did not ask for (combat end) shows the window with that focus held back.
  local holdComposerFocus = false
  local function showWithoutComposerFocus()
    holdComposerFocus = true
    local ok, err = pcall(frame.Show, frame)
    holdComposerFocus = false
    if not ok then
      error(err, 0)
    end
  end

  local onPositionChanged, onResetWindowPosition = PhoneWiring.WrapPosition(phone, options)

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
    onResetIconPosition = options.onResetIconPosition,
    onClearAllChats = options.onClearAllChats,
    onStartConversation = options.onStartConversation,
    isShown = isShown,
    windowGeometry = windowGeometry,
    frame = frame,
    refreshWindowAlpha = refreshWindowAlpha,
    onPositionChanged = onPositionChanged,
    onBack = function()
      return phone.onBack()
    end,
    theme = Theme,
    composerInput = composerInput,
    getAutoFocusChatInput = function()
      return not holdComposerFocus and settingsConfig.autoFocusComposer == true and not phone.isListView()
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
    onPositionChanged = options.onPositionChanged,
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

  if phoneLayout then
    PhoneWiring.Attach(phone, {
      factory = factory,
      frame = frame,
      layout = layout,
      chrome = chrome,
      tabToggle = contactsRuntime.tabToggle,
      composerInput = composerInput,
      windowAlpha = windowAlpha,
      windowVisibility = windowVisibility,
      windowOptions = options,
      settingsConfig = settingsConfig,
      getSelectedKey = getSelectedConversationKey,
      refreshSelection = refreshSelection,
      applyWindowSize = scriptResult.applyWindowSize,
    })
  end

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
    settingsResult = settingsResult,
    contactsRuntime = contactsRuntime,
    conversation = conversation,
    composer = composer,
    refreshSelection = refreshSelection,
    handleContactSelected = handleContactSelected,
    setScale = function(nextScale)
      local scale = windowSizing.setScale(nextScale)
      phone.dock()
      return scale
    end,
    relayoutCurrentSize = windowSizing.relayoutCurrentSize,
    refreshLanguage = refreshLanguage,
    panelHost = panelHost,
    windowVisibility = windowVisibility,
    showWithoutComposerFocus = showWithoutComposerFocus,
    phone = phoneLayout and phone or nil,
  })
end

ns.MessengerWindow = MessengerWindow

return MessengerWindow
