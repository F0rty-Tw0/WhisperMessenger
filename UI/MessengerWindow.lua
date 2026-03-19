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
local ContactsList = loadModule("WhisperMessenger.UI.ContactsList", "ContactsList")
local ConversationPane = loadModule("WhisperMessenger.UI.ConversationPane", "ConversationPane")
local Composer = loadModule("WhisperMessenger.UI.Composer", "Composer")
local function trace(...)
  if type(_G.print) == "function" then
    _G.print("[WM]", ...)
  end
end

local MessengerWindow = {}

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
      width = target.width or initialState.width,
      height = target.height or initialState.height,
      minimized = false,
    }
  end

  local function isShown(target)
    if target and target.IsShown then
      return target:IsShown()
    end

    return target ~= nil and target.shown == true
  end

  local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", parent)
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

  local contactsPane = factory.CreateFrame("Frame", nil, frame)
  contactsPane:SetSize(Theme.CONTACTS_WIDTH, initialState.height)
  contactsPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)

  local contentPane = factory.CreateFrame("Frame", nil, frame)
  contentPane:SetSize(initialState.width - Theme.CONTACTS_WIDTH, initialState.height)
  contentPane:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", 0, 0)

  local optionsPanel = factory.CreateFrame("Frame", nil, frame)
  optionsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -48)
  optionsPanel:SetSize(initialState.width - 32, initialState.height - 64)

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

  local rows = ContactsList.Render(factory, contactsPane, options.contacts or {})
  local conversation = ConversationPane.Create(factory, contentPane, options.selectedContact, options.conversation)
  local composer = Composer.Create(factory, contentPane, options.selectedContact, options.onSend or function() end)

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

  setOptionsVisible(false)

  if closeButton.SetScript then
    closeButton:SetScript("OnClick", function()
      setOptionsVisible(false)
      trace("close click")
      if options.onClose then
        options.onClose()
      elseif frame.Hide then
        frame:Hide()
      end
    end)
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
      trace("window shown")
    end)
    frame:SetScript("OnHide", function()
      trace("window hidden")
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
    contentPane = contentPane,
    closeButton = closeButton,
    optionsButton = optionsButton,
    optionsPanel = optionsPanel,
    optionsHeader = optionsHeader,
    optionsHint = optionsHint,
    resetWindowButton = resetWindowButton,
    resetIconButton = resetIconButton,
    contacts = {
      rows = rows,
    },
    conversation = conversation,
    composer = composer,
  }
end

ns.MessengerWindow = MessengerWindow

return MessengerWindow
