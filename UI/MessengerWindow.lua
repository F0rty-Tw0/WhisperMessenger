local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local function loadModule(name, key)
  if ns[key] then
    return ns[key]
  end

  local ok, loaded = pcall(require, name)
  if ok then
    return loaded
  end

  error(key .. " module not available")
end

local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")
local ScrollView = loadModule("WhisperMessenger.UI.ScrollView", "ScrollView")
local ContactsList = loadModule("WhisperMessenger.UI.ContactsList", "ContactsList")
local ConversationPane = loadModule("WhisperMessenger.UI.ConversationPane", "ConversationPane")
local Composer = loadModule("WhisperMessenger.UI.Composer", "Composer")
local function trace(...)
  if type(_G.print) == "function" then
    _G.print("[WM]", ...)
  end
end

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
  composer.sendButton.disabled = not enabled
  if composer.sendButton.SetEnabled then
    composer.sendButton:SetEnabled(enabled)
  end
end

local function sizeValue(target, getterName, fieldName, fallback)
  if target and type(target[getterName]) == "function" then
    local value = target[getterName](target)
    if type(value) == "number" and value > 0 then
      return value
    end
  end

  if target and type(target[fieldName]) == "number" then
    return target[fieldName]
  end

  return fallback
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
    local point, _, relative, offsetX, offsetY

    if target.GetPoint then
      point, _, relative, offsetX, offsetY = target:GetPoint()
    else
      local savedPoint = target.point or {}
      point, relative, offsetX, offsetY = savedPoint[1], savedPoint[3], savedPoint[4], savedPoint[5]
    end

    return {
      anchorPoint = point or initialState.anchorPoint,
      relativePoint = relative or point or initialState.anchorPoint,
      x = offsetX or 0,
      y = offsetY or 0,
      width = sizeValue(target, "GetWidth", "width", initialState.width),
      height = sizeValue(target, "GetHeight", "height", initialState.height),
      minimized = false,
    }
  end

  local function isShown(target)
    if target and target.IsShown then
      return target:IsShown()
    end

    return target ~= nil and target.shown == true
  end

  local frame = nil
  local composer = nil
  local windowIsDimmed = false
  local alphaElapsed = 0

  local function getAlpha(target, fallback)
    if target and type(target.GetAlpha) == "function" then
      local value = target:GetAlpha()

      if type(value) == "number" then
        return value
      end
    end

    if target and type(target.alpha) == "number" then
      return target.alpha
    end

    return fallback
  end

  local function hookScript(target, eventName, handler)
    if target == nil or type(target.SetScript) ~= "function" then
      return
    end

    local previous = target.GetScript and target:GetScript(eventName) or nil
    if previous == nil then
      target:SetScript(eventName, handler)
      return
    end

    target:SetScript(eventName, function(...)
      previous(...)
      handler(...)
    end)
  end

  local function isWindowEngaged()
    if composer and composer.input and type(composer.input.HasFocus) == "function" and composer.input:HasFocus() then
      return true
    end

    if frame and type(frame.IsMouseOver) == "function" and frame:IsMouseOver() then
      return true
    end

    return false
  end

  local function isExternalActivityActive()
    if type(_G.GetUnitSpeed) == "function" then
      local movementSpeed = _G.GetUnitSpeed("player")
      if type(movementSpeed) == "number" and movementSpeed > 0 then
        return true
      end
    end

    if type(_G.IsMouselooking) == "function" and _G.IsMouselooking() then
      return true
    end

    if type(_G.IsMouseButtonDown) == "function" and _G.IsMouseButtonDown() then
      return true
    end

    return false
  end

  local function applyWindowAlpha(dimmed)
    if frame == nil then
      return
    end

    local targetAlpha = dimmed and Theme.WINDOW_EXTERNAL_ACTIVITY_ALPHA or Theme.WINDOW_IDLE_ALPHA
    local currentAlpha = getAlpha(frame, Theme.WINDOW_IDLE_ALPHA)

    if currentAlpha == targetAlpha and windowIsDimmed == dimmed then
      return
    end

    if type(_G.UIFrameFadeRemoveFrame) == "function" then
      _G.UIFrameFadeRemoveFrame(frame)
    end

    if dimmed and type(_G.UIFrameFadeOut) == "function" then
      _G.UIFrameFadeOut(frame, Theme.WINDOW_ALPHA_FADE_SECONDS, currentAlpha, targetAlpha)
    elseif (not dimmed) and type(_G.UIFrameFadeIn) == "function" then
      _G.UIFrameFadeIn(frame, Theme.WINDOW_ALPHA_FADE_SECONDS, currentAlpha, targetAlpha)
    elseif frame.SetAlpha then
      frame:SetAlpha(targetAlpha)
    else
      frame.alpha = targetAlpha
    end

    windowIsDimmed = dimmed
  end

  local function refreshWindowAlpha(forceOpaque)
    if forceOpaque == true then
      applyWindowAlpha(false)
      return
    end

    applyWindowAlpha((not isWindowEngaged()) and isExternalActivityActive())
  end

  frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", parent)
  applyState(frame, initialState)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetResizable(true)
  if frame.SetResizeBounds then
    frame:SetResizeBounds(640, 420)
  elseif frame.SetMinResize then
    frame:SetMinResize(640, 420)
  end
  frame:SetClampedToScreen(true)
  local frameName = frame.GetName and frame:GetName() or frame.name
  if type(_G.UISpecialFrames) == "table" and frameName ~= nil then
    local alreadyRegistered = false
    for _, specialFrameName in ipairs(_G.UISpecialFrames) do
      if specialFrameName == frameName then
        alreadyRegistered = true
        break
      end
    end
    if not alreadyRegistered then
      table.insert(_G.UISpecialFrames, frameName)
    end
  end

  if frame.SetAlpha then
    frame:SetAlpha(Theme.WINDOW_IDLE_ALPHA)
  else
    frame.alpha = Theme.WINDOW_IDLE_ALPHA
  end

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  if background.SetColorTexture then
    background:SetColorTexture(0.05, 0.05, 0.08, 0.95)
  end
  frame.background = background

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
  title:SetText(options.title or Theme.TITLE)
  frame.title = title

  local closeButton = factory.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  closeButton:SetSize(60, 24)
  closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
  closeButton:SetText("Close")

  local optionsButton = factory.CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  optionsButton:SetSize(72, 24)
  optionsButton:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
  optionsButton:SetText("Options")

  local contactsHeight = initialState.height - Theme.TOP_BAR_HEIGHT
  local contentWidth = initialState.width - Theme.CONTACTS_WIDTH - Theme.DIVIDER_THICKNESS
  local contentHeight = initialState.height - Theme.TOP_BAR_HEIGHT
  local threadHeight = contentHeight - Theme.COMPOSER_HEIGHT - Theme.DIVIDER_THICKNESS

  local contactsPane = factory.CreateFrame("Frame", nil, frame)
  contactsPane:SetSize(Theme.CONTACTS_WIDTH, contactsHeight)
  contactsPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Theme.TOP_BAR_HEIGHT)

  local contactsView = ScrollView.Create(factory, contactsPane, {
    width = Theme.CONTACTS_WIDTH,
    height = contactsHeight,
    step = 48,
  })

  local contactsDivider = frame:CreateTexture(nil, "BORDER")
  contactsDivider:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", 0, 0)
  contactsDivider:SetSize(Theme.DIVIDER_THICKNESS, contactsHeight)
  if contactsDivider.SetColorTexture then
    contactsDivider:SetColorTexture(0.16, 0.18, 0.24, 1)
  end

  local contentPane = factory.CreateFrame("Frame", nil, frame)
  contentPane:SetSize(contentWidth, contentHeight)
  contentPane:SetPoint("TOPLEFT", frame, "TOPLEFT", Theme.CONTACTS_WIDTH + Theme.DIVIDER_THICKNESS, -Theme.TOP_BAR_HEIGHT)

  local headerDivider = frame:CreateTexture(nil, "BORDER")
  headerDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Theme.TOP_BAR_HEIGHT)
  headerDivider:SetSize(initialState.width, Theme.DIVIDER_THICKNESS)
  if headerDivider.SetColorTexture then
    headerDivider:SetColorTexture(0.16, 0.18, 0.24, 1)
  end

  local threadPane = factory.CreateFrame("Frame", nil, contentPane)
  threadPane:SetSize(contentWidth, threadHeight)
  threadPane:SetPoint("TOPLEFT", contentPane, "TOPLEFT", 0, 0)

  local composerPane = factory.CreateFrame("Frame", nil, contentPane)
  composerPane:SetSize(contentWidth, Theme.COMPOSER_HEIGHT)
  composerPane:SetPoint("BOTTOMLEFT", contentPane, "BOTTOMLEFT", 0, 0)

  local composerDivider = contentPane:CreateTexture(nil, "BORDER")
  composerDivider:SetPoint("BOTTOMLEFT", threadPane, "BOTTOMLEFT", 0, -Theme.DIVIDER_THICKNESS)
  composerDivider:SetSize(contentWidth, Theme.DIVIDER_THICKNESS)
  if composerDivider.SetColorTexture then
    composerDivider:SetColorTexture(0.16, 0.18, 0.24, 1)
  end

  local optionsPanel = factory.CreateFrame("Frame", nil, frame)
  optionsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", Theme.CONTENT_PADDING, -(Theme.TOP_BAR_HEIGHT + Theme.CONTENT_PADDING))
  optionsPanel:SetSize(initialState.width - (Theme.CONTENT_PADDING * 2), initialState.height - Theme.TOP_BAR_HEIGHT - (Theme.CONTENT_PADDING * 2))

  local optionsHeader = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  optionsHeader:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 0, 0)
  optionsHeader:SetText("Options")

  local optionsHint = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  optionsHint:SetPoint("TOPLEFT", optionsHeader, "BOTTOMLEFT", 0, -12)
  optionsHint:SetText("Reset the messenger and icon to their default positions.")

  local resetWindowButton = factory.CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
  resetWindowButton:SetSize(180, 24)
  resetWindowButton:SetPoint("TOPLEFT", optionsHint, "BOTTOMLEFT", 0, -16)
  resetWindowButton:SetText("Reset Window Position")

  local resetIconButton = factory.CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
  resetIconButton:SetSize(160, 24)
  resetIconButton:SetPoint("TOPLEFT", resetWindowButton, "BOTTOMLEFT", 0, -10)
  resetIconButton:SetText("Reset Icon Position")

  local currentSelectedContact = nil
  local currentConversation = nil
  local currentStatus = nil
  local currentContacts = options.contacts or {}
  local composerSelectedContact = {}
  local handleContactSelected
  local contacts = {
    rows = {},
    scrollFrame = contactsView.scrollFrame,
    scrollBar = contactsView.scrollBar,
    content = contactsView.content,
    view = contactsView,
  }

  local function refreshContacts(nextContacts, selectedConversationKey)
    if nextContacts ~= nil then
      currentContacts = nextContacts
    end

    contacts.rows = ContactsList.Refresh(factory, contacts.content, contacts.rows, currentContacts, {
      selectedConversationKey = selectedConversationKey,
      onSelect = function(item)
        if handleContactSelected then
          handleContactSelected(item)
        end
      end,
    })
    ScrollView.Sync(contacts.view)

    return contacts.rows
  end

  refreshContacts(currentContacts, options.selectedContact and options.selectedContact.conversationKey or nil)
  local conversation = ConversationPane.Create(factory, threadPane, options.selectedContact, options.conversation)

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

  composer = Composer.Create(factory, composerPane, composerSelectedContact, options.onSend or function() end, closeWindow)
  hookScript(composer.input, "OnEditFocusGained", function()
    refreshWindowAlpha(true)
  end)
  hookScript(composer.input, "OnEditFocusLost", function()
    refreshWindowAlpha()
  end)

  local function refreshSelection(nextState)
    nextState = nextState or {}
    currentSelectedContact = nextState.selectedContact
    currentConversation = nextState.conversation
    currentStatus = nextState.status

    refreshContacts(nextState.contacts, currentSelectedContact and currentSelectedContact.conversationKey or nil)
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

  refreshSelection({
    contacts = currentContacts,
    selectedContact = options.selectedContact,
    conversation = options.conversation,
    status = options.status,
  })

  setOptionsVisible(false)

  if closeButton.SetScript then
    closeButton:SetScript("OnClick", closeWindow)
  end

  if optionsButton.SetScript then
    optionsButton:SetScript("OnClick", function()
      setOptionsVisible(not isShown(optionsPanel))
    end)
  end

  if resetWindowButton.SetScript then
    resetWindowButton:SetScript("OnClick", function()
      if options.onResetWindowPosition == nil then
        return
      end

      local nextState = options.onResetWindowPosition()
      if nextState ~= nil then
        applyState(frame, nextState)
      end
    end)
  end

  if resetIconButton.SetScript then
    resetIconButton:SetScript("OnClick", function()
      if options.onResetIconPosition then
        options.onResetIconPosition()
      end
    end)
  end

  if frame.SetScript then
    frame:SetScript("OnShow", function()
      alphaElapsed = 0
      refreshWindowAlpha(true)
      trace("window shown")
    end)
    frame:SetScript("OnHide", function()
      alphaElapsed = 0
      trace("window hidden")
    end)
    frame:SetScript("OnEnter", function()
      refreshWindowAlpha(true)
    end)
    frame:SetScript("OnLeave", function()
      refreshWindowAlpha()
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
      alphaElapsed = alphaElapsed + (elapsed or 0)

      if alphaElapsed < Theme.WINDOW_ALPHA_UPDATE_INTERVAL then
        return
      end

      alphaElapsed = 0
      refreshWindowAlpha()
    end)
    frame:SetScript("OnDragStart", function(self)
      if self.IsMovable == nil or self:IsMovable() then
        self:StartMoving()
        trace("window drag start")
      end
    end)
    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()

      local nextState = buildState(self)
      trace("window drag stop", nextState.anchorPoint, nextState.x, nextState.y)
      if options.onPositionChanged then
        options.onPositionChanged(nextState)
      end
    end)
  end

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