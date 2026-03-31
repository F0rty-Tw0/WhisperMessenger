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
local ContactsController = ns.MessengerWindowContactsController
  or require("WhisperMessenger.UI.MessengerWindow.ContactsController")
local GeneralSettings = ns.GeneralSettings or require("WhisperMessenger.UI.MessengerWindow.GeneralSettings")
local AppearanceSettings = ns.AppearanceSettings or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local BehaviorSettings = ns.BehaviorSettings or require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local NotificationSettings = ns.NotificationSettings
  or require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
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

local function setComposerEnabled(composer, selectedContact, noticeText)
  local enabled = selectedContact ~= nil and not (noticeText and noticeText ~= "")
  if composer.setEnabled then
    composer.setEnabled(enabled)
  end
end

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
  local currentContactsWidth =
    LayoutBuilder.ClampContactsWidth(initialState.width, state.contactsWidth or Theme.CONTACTS_WIDTH, Theme)

  local function applyState(target, nextState)
    local clampedState = WindowBounds.ClampState(parent, nextState, Theme)
    currentContactsWidth =
      LayoutBuilder.ClampContactsWidth(clampedState.width, clampedState.contactsWidth or Theme.CONTACTS_WIDTH, Theme)
    target:SetSize(clampedState.width or Theme.WINDOW_WIDTH, clampedState.height or Theme.WINDOW_HEIGHT)
    target:SetPoint(
      clampedState.anchorPoint or "CENTER",
      parent,
      clampedState.relativePoint or clampedState.anchorPoint or "CENTER",
      clampedState.x or 0,
      clampedState.y or 0
    )
    return clampedState
  end

  local function buildState(target)
    local pos = captureFramePosition(target)
    pos.width = sizeValue(target, "GetWidth", "width", initialState.width)
    pos.height = sizeValue(target, "GetHeight", "height", initialState.height)
    pos.contactsWidth = LayoutBuilder.ClampContactsWidth(pos.width, currentContactsWidth, Theme)
    pos.minimized = false
    return WindowBounds.ClampState(parent, pos, Theme)
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

  -- Settings config (must be available before layout and alpha wiring)
  local settingsConfig = options.settingsConfig or {}

  -- Build layout (panes)
  local layout = LayoutBuilder.Build(factory, frame, initialState, { contactsWidth = currentContactsWidth })
  currentContactsWidth = layout.contactsWidth or currentContactsWidth
  local contactsPane = layout.contactsPane
  local contactsDivider = layout.contactsDivider
  local contactsResizeHandle = layout.contactsResizeHandle
  local contentPane = layout.contentPane
  local headerDivider = layout.headerDivider
  local threadPane = layout.threadPane
  local composerPane = layout.composerPane
  local composerDivider = layout.composerDivider
  local optionsPanel = layout.optionsPanel
  local optionsMenu = layout.optionsMenu
  local optionsContentPane = layout.optionsContentPane
  local optionsScrollContent = layout.optionsScrollView and layout.optionsScrollView.content or optionsContentPane
  local generalTab = layout.generalTab
  local appearanceTab = layout.appearanceTab
  local behaviorTab = layout.behaviorTab
  local notificationsTab = layout.notificationsTab
  local optionsHeader = layout.optionsHeader
  local optionsHint = layout.optionsHint
  local resetWindowButton = layout.resetWindowButton
  local resetIconButton = layout.resetIconButton
  local clearAllChatsButton = layout.clearAllChatsButton
  local contactsView = layout.contactsView
  local contactsSearchInput = layout.contactsSearchInput
  local contactsSearchClearButton = layout.contactsSearchClearButton
  local contactsSearchPlaceholder = layout.contactsSearchPlaceholder
  -- Compose settings panels (each inside its own frame within optionsContentPane)
  local storeConfig = options.storeConfig or {}

  local function onSettingChanged(key, value)
    if options.onSettingChanged then
      options.onSettingChanged(key, value)
    end
  end

  local function createSettingsPanel(createSettingsView, config)
    local panel = factory.CreateFrame("Frame", nil, optionsScrollContent)
    panel:SetAllPoints(optionsScrollContent)
    local settings = createSettingsView(factory, panel, config, {
      onChange = onSettingChanged,
    })
    return panel, settings
  end

  local generalPanel, generalSettings = createSettingsPanel(GeneralSettings.Create, {
    maxMessagesPerConversation = storeConfig.maxMessagesPerConversation or 200,
    maxConversations = storeConfig.maxConversations or 100,
    messageMaxAge = storeConfig.messageMaxAge or 86400,
    clearOnLogout = settingsConfig.clearOnLogout,
    hideMessagePreview = settingsConfig.hideMessagePreview,
  })

  local appearancePanel, appearanceSettings = createSettingsPanel(AppearanceSettings.Create, {
    fontFamily = settingsConfig.fontFamily,
    windowOpacityInactive = settingsConfig.windowOpacityInactive,
    windowOpacityActive = settingsConfig.windowOpacityActive,
  })

  local behaviorPanel, behaviorSettings = createSettingsPanel(BehaviorSettings.Create, {
    dimWhenMoving = settingsConfig.dimWhenMoving,
    autoFocusComposer = settingsConfig.autoFocusComposer,
    autoSelectUnread = settingsConfig.autoSelectUnread,
    hideFromDefaultChat = settingsConfig.hideFromDefaultChat,
    autoOpenWindow = settingsConfig.autoOpenWindow,
  })

  local notificationsPanel, notificationSettings = createSettingsPanel(NotificationSettings.Create, {
    badgePulse = settingsConfig.badgePulse,
    playSoundOnWhisper = settingsConfig.playSoundOnWhisper,
    showUnreadBadge = settingsConfig.showUnreadBadge,
  })

  -- Contacts controller (manages rows, paging, scroll hooks)
  local handleContactSelected -- forward declaration
  local contactsController = ContactsController.Create(factory, contactsView, options.contacts or {}, {
    getHideMessagePreview = function()
      return settingsConfig.hideMessagePreview == true
    end,
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
  local currentContacts = options.contacts or {}
  local contactsSearchQuery = ""

  local function normalizeSearchQuery(rawText)
    if type(rawText) ~= "string" then
      return ""
    end

    local normalized = string.lower(rawText)
    normalized = string.gsub(normalized, "^%s+", "")
    normalized = string.gsub(normalized, "%s+$", "")
    return normalized
  end

  local function buildSearchTerms(normalizedQuery)
    local terms = {}
    for term in string.gmatch(normalizedQuery, "%S+") do
      terms[#terms + 1] = term
    end
    return terms
  end

  local function itemMatchesSearch(item, terms)
    if #terms == 0 then
      return true
    end
    if type(item) ~= "table" then
      return false
    end

    local haystack = item.searchText or item.displayName or ""
    if haystack == "" then
      return false
    end

    local loweredHaystack = string.lower(haystack)
    for _, term in ipairs(terms) do
      if string.find(loweredHaystack, term, 1, true) == nil then
        return false
      end
    end
    return true
  end

  local function isConversationVisible(items, conversationKey)
    if conversationKey == nil then
      return false
    end

    for _, item in ipairs(items or {}) do
      if item and item.conversationKey == conversationKey then
        return true
      end
    end
    return false
  end

  local function syncSearchInputVisual()
    local hasSearch = contactsSearchQuery ~= ""
    if contactsSearchPlaceholder and contactsSearchPlaceholder.SetShown then
      contactsSearchPlaceholder:SetShown(not hasSearch)
    end
    if contactsSearchClearButton and contactsSearchClearButton.SetShown then
      contactsSearchClearButton:SetShown(hasSearch)
    end
  end

  local function buildVisibleContacts()
    local visible = {}
    local terms = buildSearchTerms(contactsSearchQuery)
    for _, item in ipairs(currentContacts or {}) do
      if itemMatchesSearch(item, terms) then
        visible[#visible + 1] = item
      end
    end
    return visible
  end

  local function refreshContacts(nextContacts, selectedConversationKey, resetPaging)
    if nextContacts ~= nil then
      currentContacts = nextContacts
    end

    local visibleContacts = buildVisibleContacts()
    local selectedKey = selectedConversationKey
    if selectedKey ~= nil and not isConversationVisible(visibleContacts, selectedKey) then
      selectedKey = nil
    end

    contactsController.rows = contactsController.refresh(visibleContacts, selectedKey, resetPaging)
    contacts.rows = contactsController.rows
    syncSearchInputVisual()
    return contacts.rows
  end

  if contactsSearchInput and contactsSearchInput.SetScript then
    contactsSearchInput:SetScript("OnTextChanged", function()
      local searchText = contactsSearchInput.GetText and contactsSearchInput:GetText() or contactsSearchInput.text or ""
      contactsSearchQuery = normalizeSearchQuery(searchText)
      refreshContacts(nil, currentSelectedContact and currentSelectedContact.conversationKey or nil, true)
    end)
    contactsSearchInput:SetScript("OnEscapePressed", function()
      if contactsSearchInput.SetText then
        contactsSearchInput:SetText("")
      else
        contactsSearchInput.text = ""
      end
      contactsSearchQuery = ""
      refreshContacts(nil, currentSelectedContact and currentSelectedContact.conversationKey or nil, true)
      if contactsSearchInput.ClearFocus then
        contactsSearchInput:ClearFocus()
      end
    end)
  end

  if contactsSearchClearButton and contactsSearchClearButton.SetScript then
    contactsSearchClearButton:SetScript("OnClick", function()
      if contactsSearchInput and contactsSearchInput.SetText then
        contactsSearchInput:SetText("")
      elseif contactsSearchInput then
        contactsSearchInput.text = ""
      end
      contactsSearchQuery = ""
      refreshContacts(nil, currentSelectedContact and currentSelectedContact.conversationKey or nil, true)
    end)
  end
  syncSearchInputVisual()

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

  local function getAlphaSettings()
    return {
      dimWhenMoving = settingsConfig.dimWhenMoving,
      windowOpacityActive = settingsConfig.windowOpacityActive,
      windowOpacityInactive = settingsConfig.windowOpacityInactive,
    }
  end

  AlphaController.hookScript(composerInput, "OnEditFocusGained", function()
    AlphaController.refreshWindowAlpha(frame, composerInput, windowState, true, getAlphaSettings())
  end)
  AlphaController.hookScript(composerInput, "OnEditFocusLost", function()
    AlphaController.refreshWindowAlpha(frame, composerInput, windowState, false, getAlphaSettings())
  end)

  local function refreshWindowAlpha(forceOpaque)
    AlphaController.refreshWindowAlpha(frame, composerInput, windowState, forceOpaque, getAlphaSettings())
  end

  -- Selection management
  local currentConversation = nil
  local currentStatus = nil
  local currentNotice = nil

  local function refreshSelection(nextState, resetPaging)
    nextState = nextState or {}
    currentSelectedContact = nextState.selectedContact
    currentConversation = nextState.conversation
    currentStatus = nextState.status
    currentNotice = nextState.notice

    refreshContacts(
      nextState.contacts,
      currentSelectedContact and currentSelectedContact.conversationKey or nil,
      resetPaging
    )
    ConversationPane.Refresh(conversation, currentSelectedContact, currentConversation, currentStatus, currentNotice)
    syncComposerSelectedContact(composerSelectedContact, currentSelectedContact)
    setComposerEnabled(composer, currentSelectedContact, currentNotice)
  end

  local function relayoutWindow(w, h, requestedContactsWidth, refreshContactsLayout)
    local metrics = LayoutBuilder.Relayout(layout, w, h, requestedContactsWidth)
    currentContactsWidth = metrics.contactsWidth or currentContactsWidth

    if composer and composer.relayout then
      composer.relayout(metrics.contentWidth)
    end
    if contactsController and contactsController.fillViewport then
      contactsController.fillViewport(metrics.contactsListHeight or metrics.contactsHeight)
    end
    if conversation then
      ConversationPane.Relayout(conversation, metrics.contentWidth, metrics.threadHeight)
    end
    if refreshContactsLayout then
      refreshContacts(nil, currentSelectedContact and currentSelectedContact.conversationKey or nil, false)
    end
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
    settingsTabs = { generalTab, appearanceTab, behaviorTab, notificationsTab },
    settingsPanels = { generalPanel, appearancePanel, behaviorPanel, notificationsPanel },
  }, {
    onClose = closeWindow,
    onResetWindowPosition = options.onResetWindowPosition,
    onResetIconPosition = options.onResetIconPosition,
    onClearAllChats = options.onClearAllChats,
    setOptionsVisible = setOptionsVisible,
    isShown = isShown,
    applyState = function(nextState)
      local appliedState = applyState(frame, nextState)
      relayoutWindow(appliedState.width, appliedState.height, appliedState.contactsWidth, true)
    end,
    refreshSelection = refreshSelection,
  })

  -- Frame-level scripts
  WindowScripts.WireFrame({
    frame = frame,
    resizeGrip = resizeGrip,
    contactsResizeHandle = contactsResizeHandle,
  }, {
    refreshWindowAlpha = refreshWindowAlpha,
    layout = layout,
    composer = composer,
    contactsController = contactsController,
    conversation = conversation,
    relayout = relayoutWindow,
    buildState = buildState,
    trace = trace,
    onPositionChanged = options.onPositionChanged,
    Theme = Theme,
    composerInput = composerInput,
    getAutoFocusChatInput = function()
      return settingsConfig.autoFocusComposer == true
    end,
  })

  local function buildFacade()
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
      optionsMenu = optionsMenu,
      optionsContentPane = optionsContentPane,
      generalTab = generalTab,
      appearanceTab = appearanceTab,
      behaviorTab = behaviorTab,
      notificationsTab = notificationsTab,
      generalSettings = generalSettings,
      appearanceSettings = appearanceSettings,
      behaviorSettings = behaviorSettings,
      notificationSettings = notificationSettings,
      optionsHeader = optionsHeader,
      optionsHint = optionsHint,
      resetWindowButton = resetWindowButton,
      resetIconButton = resetIconButton,
      clearAllChatsButton = clearAllChatsButton,
      contactsSearchInput = contactsSearchInput,
      contactsSearchClearButton = contactsSearchClearButton,
      contactsSearchPlaceholder = contactsSearchPlaceholder,
      resizeGrip = resizeGrip,
      contactsResizeHandle = contactsResizeHandle,
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

  trace("window created", initialState.anchorPoint, initialState.x, initialState.y)

  return buildFacade()
end

ns.MessengerWindow = MessengerWindow

return MessengerWindow
