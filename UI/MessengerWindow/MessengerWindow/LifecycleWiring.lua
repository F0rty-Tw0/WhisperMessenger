local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local Buttons = ns.MessengerWindowWindowScriptsButtons or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons")
local Frame = ns.MessengerWindowWindowScriptsFrame or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame")
local RelayoutController = ns.MessengerWindowRelayoutController or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.RelayoutController")

local LifecycleWiring = {}

function LifecycleWiring.Setup(options)
  options = options or {}

  local chrome = options.chrome
  local layout = options.layout

  local relayoutController = RelayoutController.Create({
    layoutBuilder = LayoutBuilder,
    layout = layout,
    setContactsWidth = options.setContactsWidth,
    composer = options.composer,
    contactsController = options.contactsController,
    conversation = options.conversation,
    conversationPane = ConversationPane,
    refreshContacts = options.refreshContacts,
    getSelectedConversationKey = options.getSelectedConversationKey,
  })
  local relayoutWindow = relayoutController.relayoutWindow

  options.refreshContacts(options.getCurrentContacts(), options.selectedContact and options.selectedContact.conversationKey or nil, true)

  options.refreshSelection({
    contacts = options.getCurrentContacts(),
    selectedContact = options.selectedContact,
    conversation = options.initialConversation,
    status = options.initialStatus,
  }, true)

  options.setOptionsVisible(false)

  local scriptResult = Buttons.WireButtons({
    closeButton = chrome.closeButton,
    optionsButton = chrome.optionsButton,
    backButton = chrome.backButton,
    newConversationButton = chrome.newConversationButton,
    resetWindowButton = layout.resetWindowButton,
    resetIconButton = layout.resetIconButton,
    clearAllChatsButton = layout.clearAllChatsButton,
    optionsPanel = layout.optionsPanel,
    settingsTabs = layout.settingsTabs,
    settingsPanels = options.settingsPanels,
    optionsScrollView = layout.optionsScrollView,
  }, {
    onClose = options.closeWindow,
    onStartConversation = options.onStartConversation,
    onResetWindowPosition = options.onResetWindowPosition,
    onResetIconPosition = options.onResetIconPosition,
    onClearAllChats = options.onClearAllChats,
    setOptionsVisible = options.setOptionsVisible,
    isShown = options.isShown,
    applyState = function(nextState)
      local appliedState = options.windowGeometry.applyState(options.frame, nextState)
      relayoutWindow(appliedState.width, appliedState.height, appliedState.contactsWidth, true)
      if options.onStateApplied then
        options.onStateApplied(appliedState)
      end
    end,
    refreshSelection = options.refreshSelection,
  }) or {}
  local frameResult = Frame.WireFrame({
    frame = options.frame,
    resizeGrip = chrome.resizeGrip,
    contactsResizeHandle = layout.contactsResizeHandle,
  }, {
    refreshWindowAlpha = options.refreshWindowAlpha,
    layout = layout,
    composer = options.composer,
    contactsController = options.contactsController,
    conversation = options.conversation,
    relayout = relayoutWindow,
    buildState = options.windowGeometry.buildState,
    onPositionChanged = options.onPositionChanged,
    Theme = options.theme,
    composerInput = options.composerInput,
    getAutoFocusChatInput = options.getAutoFocusChatInput,
    isContactsCollapsed = options.isContactsCollapsed,
    setContactsCollapsed = options.setContactsCollapsed,
  })
  if frameResult and frameResult.withSizeChangedRelayoutSuppressed then
    scriptResult.withSizeChangedRelayoutSuppressed = frameResult.withSizeChangedRelayoutSuppressed
  end
  if frameResult and frameResult.applyWindowSize then
    scriptResult.applyWindowSize = frameResult.applyWindowSize
  end

  return relayoutWindow, scriptResult
end

ns.MessengerWindowLifecycleWiring = LifecycleWiring

return LifecycleWiring
