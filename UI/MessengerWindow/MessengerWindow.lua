local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local Composer = ns.Composer or require("WhisperMessenger.UI.Composer")
local AlphaController = ns.MessengerWindowAlphaController
  or require("WhisperMessenger.UI.MessengerWindow.AlphaController")
local ChromeBuilder = ns.MessengerWindowChromeBuilder or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local WindowScripts = ns.MessengerWindowWindowScripts or require("WhisperMessenger.UI.MessengerWindow.WindowScripts")
local ContactsController = ns.MessengerWindowContactsController
  or require("WhisperMessenger.UI.MessengerWindow.ContactsController")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local trace = ns.trace or require("WhisperMessenger.Core.Trace")

local sizeValue = UIHelpers.sizeValue
local captureFramePosition = UIHelpers.captureFramePosition

local MessengerWindow = {}

local function syncComposerSelectedContact(target, selectedContact)
  target.conversationKey = selectedContact and selectedContact.conversationKey or nil
  target.displayName = selectedContact and selectedContact.displayName or nil
  target.channel = selectedContact and selectedContact.channel or nil
  target.bnetAccountID = selectedContact and selectedContact.bnetAccountID or nil
  target.guid = selectedContact and selectedContact.guid or nil
  target.gameAccountName = selectedContact and selectedContact.gameAccountName or nil
end

local function setComposerEnabled(composer, selectedContact)
  local enabled = selectedContact ~= nil
  if composer.setEnabled then
    composer.setEnabled(enabled)
  end
end

function MessengerWindow.Create(factory, options)
  options = options or {}

  local parent = options.parent or _G.UIParent
  local state = options.state or {}
  local initialState = {
    anchorPoint = state.anchorPoint or "CENTER",
    relativePoint = state.relativePoint or state.anchorPoint or "CENTER",
    x = state.x or 0,
    y = state.y or 0,
    width = state.width or Theme.WINDOW_WIDTH,
    height = state.height or Theme.WINDOW_HEIGHT,
    minimized = state.minimized or false,
  }

  local function applyState(target, nextState)
    target:SetSize(nextState.width or Theme.WINDOW_WIDTH, nextState.height or Theme.WINDOW_HEIGHT)
    target:SetPoint(
      nextState.anchorPoint or "CENTER",
      parent,
      nextState.relativePoint or nextState.anchorPoint or "CENTER",
      nextState.x or 0,
      nextState.y or 0
    )
  end

  local function buildState(target)
    local pos = captureFramePosition(target)
    pos.width = sizeValue(target, "GetWidth", "width", initialState.width)
    pos.height = sizeValue(target, "GetHeight", "height", initialState.height)
    pos.minimized = false
    return pos
  end

  local function isShown(target)
    if target and target.IsShown then
      return target:IsShown()
    end
    return target ~= nil and target.shown == true
  end

  -- Mutable state passed into AlphaController to track dimmed state
  local windowState = { isDimmed = false }

  -- Build chrome (outer frame, buttons, etc.)
  local chrome = ChromeBuilder.Build(factory, parent, initialState, { title = options.title })
  local frame = chrome.frame
  local title = chrome.title
  local closeButton = chrome.closeButton
  local optionsButton = chrome.optionsButton
  local resizeGrip = chrome.resizeGrip

  -- Build layout (panes)
  local layout = LayoutBuilder.Build(factory, frame, initialState, {})
  local contactsPane = layout.contactsPane
  local contactsDivider = layout.contactsDivider
  local contentPane = layout.contentPane
  local headerDivider = layout.headerDivider
  local threadPane = layout.threadPane
  local composerPane = layout.composerPane
  local composerDivider = layout.composerDivider
  local optionsPanel = layout.optionsPanel
  local optionsHeader = layout.optionsHeader
  local optionsHint = layout.optionsHint
  local resetWindowButton = layout.resetWindowButton
  local resetIconButton = layout.resetIconButton
  local clearAllChatsButton = layout.clearAllChatsButton
  local contactsView = layout.contactsView

  -- Contacts controller (manages rows, paging, scroll hooks)
  local handleContactSelected -- forward declaration
  local contactsController = ContactsController.Create(factory, contactsView, options.contacts or {}, {
    onSelect = function(item)
      if handleContactSelected then
        handleContactSelected(item)
      end
    end,
    onPin = function(item)
      if options.onPin then
        options.onPin(item)
      end
    end,
    onRemove = function(item)
      if options.onRemove then
        options.onRemove(item)
      end
    end,
    onReorder = function(orders)
      if options.onReorder then
        options.onReorder(orders)
      end
    end,
  })

  -- Expose contacts in the same shape as before
  local contacts = {
    rows = contactsController.rows,
    scrollFrame = contactsController.scrollFrame,
    scrollBar = contactsController.scrollBar,
    content = contactsController.content,
    view = contactsController.view,
  }

  -- Wrapper so the facade keeps a single refreshContacts reference
  local currentSelectedContact = nil
  local function refreshContacts(nextContacts, selectedConversationKey, resetPaging)
    contactsController.rows = contactsController.refresh(nextContacts, selectedConversationKey, resetPaging)
    contacts.rows = contactsController.rows
    return contacts.rows
  end

  -- Conversation pane
  local conversation = ConversationPane.Create(factory, threadPane, options.selectedContact, options.conversation)

  -- Composer (created before wiring alpha so we have composer.input)
  local composerSelectedContact = {}
  local composer

  local function setOptionsVisible(nextVisible)
    if nextVisible then
      optionsPanel:Show()
      contactsPane:Hide()
      contentPane:Hide()
      trace("options shown")
      return
    end
    optionsPanel:Hide()
    contactsPane:Show()
    contentPane:Show()
    trace("options hidden")
  end

  local function closeWindow()
    setOptionsVisible(false)
    trace("close click")
    if options.onClose then
      options.onClose()
    elseif frame.Hide then
      frame:Hide()
    end
  end

  composer =
    Composer.Create(factory, composerPane, composerSelectedContact, options.onSend or function() end, closeWindow)

  -- Alpha helpers (capture composer.input now that composer exists)
  local composerInput = composer.input

  AlphaController.hookScript(composerInput, "OnEditFocusGained", function()
    AlphaController.refreshWindowAlpha(frame, composerInput, windowState, true)
  end)
  AlphaController.hookScript(composerInput, "OnEditFocusLost", function()
    AlphaController.refreshWindowAlpha(frame, composerInput, windowState)
  end)

  local function refreshWindowAlpha(forceOpaque)
    AlphaController.refreshWindowAlpha(frame, composerInput, windowState, forceOpaque)
  end

  -- Selection management
  local currentConversation = nil
  local currentStatus = nil
  local currentContacts = options.contacts or {}

  local function refreshSelection(nextState, resetPaging)
    nextState = nextState or {}
    currentSelectedContact = nextState.selectedContact
    currentConversation = nextState.conversation
    currentStatus = nextState.status

    refreshContacts(
      nextState.contacts,
      currentSelectedContact and currentSelectedContact.conversationKey or nil,
      resetPaging
    )
    ConversationPane.Refresh(conversation, currentSelectedContact, currentConversation, currentStatus)
    syncComposerSelectedContact(composerSelectedContact, currentSelectedContact)
    setComposerEnabled(composer, currentSelectedContact)
  end

  local function buildSelectedState(item)
    local nextState = nil
    if options.onSelectConversation then
      nextState = options.onSelectConversation(item.conversationKey, item)
    end
    if nextState == nil then
      nextState = {
        selectedContact = options.getSelectedContact and options.getSelectedContact(item.conversationKey, item) or item,
        conversation = options.getConversation and options.getConversation(item.conversationKey, item) or nil,
        status = options.getStatus and options.getStatus(item.conversationKey, item) or nil,
      }
    elseif nextState.selectedContact == nil then
      nextState.selectedContact = item
    end
    return nextState
  end

  handleContactSelected = function(item)
    refreshSelection(buildSelectedState(item))
  end

  -- Initial render
  refreshContacts(currentContacts, options.selectedContact and options.selectedContact.conversationKey or nil, true)

  refreshSelection({
    contacts = currentContacts,
    selectedContact = options.selectedContact,
    conversation = options.conversation,
    status = options.status,
  }, true)

  setOptionsVisible(false)

  -- Wire button scripts
  WindowScripts.WireButtons({
    closeButton = closeButton,
    optionsButton = optionsButton,
    resetWindowButton = resetWindowButton,
    resetIconButton = resetIconButton,
    clearAllChatsButton = clearAllChatsButton,
    optionsPanel = optionsPanel,
  }, {
    onClose = closeWindow,
    onResetWindowPosition = options.onResetWindowPosition,
    onResetIconPosition = options.onResetIconPosition,
    onClearAllChats = options.onClearAllChats,
    setOptionsVisible = setOptionsVisible,
    isShown = isShown,
    applyState = function(nextState)
      applyState(frame, nextState)
    end,
    refreshSelection = refreshSelection,
  })

  -- Frame-level scripts
  WindowScripts.WireFrame({
    frame = frame,
    resizeGrip = resizeGrip,
  }, {
    refreshWindowAlpha = refreshWindowAlpha,
    layout = layout,
    composer = composer,
    contactsController = contactsController,
    conversation = conversation,
    buildState = buildState,
    trace = trace,
    onPositionChanged = options.onPositionChanged,
    Theme = Theme,
  })

  trace("window created", initialState.anchorPoint, initialState.x, initialState.y)

  return {
    frame = frame,
    title = title,
    contactsPane = contactsPane,
    contactsDivider = contactsDivider,
    contentPane = contentPane,
    headerDivider = headerDivider,
    threadPane = threadPane,
    composerPane = composerPane,
    composerDivider = composerDivider,
    closeButton = closeButton,
    optionsButton = optionsButton,
    optionsPanel = optionsPanel,
    optionsHeader = optionsHeader,
    optionsHint = optionsHint,
    resetWindowButton = resetWindowButton,
    resetIconButton = resetIconButton,
    clearAllChatsButton = clearAllChatsButton,
    resizeGrip = resizeGrip,
    contacts = contacts,
    conversation = conversation,
    composer = composer,
    refreshContacts = refreshContacts,
    refreshSelection = refreshSelection,
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
