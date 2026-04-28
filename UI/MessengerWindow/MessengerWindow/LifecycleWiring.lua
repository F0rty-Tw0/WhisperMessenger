local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local LifecycleWiring = {}

function LifecycleWiring.Setup(options)
  options = options or {}

  local chrome = options.chrome
  local layout = options.layout

  local relayoutController = options.relayoutFactory.Create({
    layoutBuilder = options.layoutBuilder,
    layout = layout,
    setContactsWidth = options.setContactsWidth,
    composer = options.composer,
    contactsController = options.contactsController,
    conversation = options.conversation,
    conversationPane = options.conversationPane,
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

  options.scriptWiring.Wire({
    windowScripts = options.windowScripts,
    buttonsRefs = {
      closeButton = chrome.closeButton,
      optionsButton = chrome.optionsButton,
      newConversationButton = chrome.newConversationButton,
      resetWindowButton = layout.resetWindowButton,
      resetIconButton = layout.resetIconButton,
      clearAllChatsButton = layout.clearAllChatsButton,
      optionsPanel = layout.optionsPanel,
      settingsTabs = { layout.generalTab, layout.appearanceTab, layout.behaviorTab, layout.notificationsTab },
      settingsPanels = options.settingsPanels,
      optionsScrollView = layout.optionsScrollView,
    },
    buttonsCallbacks = {
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
      end,
      refreshSelection = options.refreshSelection,
    },
    frameRefs = {
      frame = options.frame,
      resizeGrip = chrome.resizeGrip,
      contactsResizeHandle = layout.contactsResizeHandle,
    },
    frameCallbacks = {
      refreshWindowAlpha = options.refreshWindowAlpha,
      layout = layout,
      composer = options.composer,
      contactsController = options.contactsController,
      conversation = options.conversation,
      relayout = relayoutWindow,
      buildState = options.windowGeometry.buildState,
      trace = options.trace,
      onPositionChanged = options.onPositionChanged,
      Theme = options.theme,
      composerInput = options.composerInput,
      getAutoFocusChatInput = options.getAutoFocusChatInput,
    },
  })

  return relayoutWindow
end

ns.MessengerWindowLifecycleWiring = LifecycleWiring

return LifecycleWiring
