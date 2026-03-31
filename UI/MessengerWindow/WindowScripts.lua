local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")

local WindowScripts = {}

-- Wire close, options, reset-window, reset-icon, clear-all-chats, and
-- settings tab buttons.
--
-- refs:
--   closeButton, optionsButton, resetWindowButton, resetIconButton,
--   clearAllChatsButton, optionsPanel, settingsPanels, settingsTabs
--
-- options:
--   onClose, onResetWindowPosition, onResetIconPosition, onClearAllChats,
--   setOptionsVisible, isShown, applyState, refreshSelection
function WindowScripts.WireButtons(refs, options)
  local closeButton = refs.closeButton
  local optionsButton = refs.optionsButton
  local resetWindowButton = refs.resetWindowButton
  local resetIconButton = refs.resetIconButton
  local clearAllChatsButton = refs.clearAllChatsButton
  local optionsPanel = refs.optionsPanel
  local settingsPanels = refs.settingsPanels or {}
  local settingsTabs = refs.settingsTabs or {}

  if closeButton and closeButton.SetScript then
    closeButton:SetScript("OnClick", function()
      options.onClose()
    end)
  end

  if optionsButton and optionsButton.SetScript then
    optionsButton:SetScript("OnClick", function()
      options.setOptionsVisible(not options.isShown(optionsPanel))
    end)
  end

  if resetWindowButton and resetWindowButton.SetScript then
    resetWindowButton:SetScript("OnClick", function()
      if options.onResetWindowPosition == nil then
        return
      end
      local nextState = options.onResetWindowPosition()
      if nextState ~= nil then
        options.applyState(nextState)
      end
    end)
  end

  if resetIconButton and resetIconButton.SetScript then
    resetIconButton:SetScript("OnClick", function()
      if options.onResetIconPosition then
        options.onResetIconPosition()
      end
    end)
  end

  if clearAllChatsButton and clearAllChatsButton.SetScript then
    local dialogName = "WHISPER_MESSENGER_CLEAR_ALL_CHATS"
    if not _G.StaticPopupDialogs then
      _G.StaticPopupDialogs = {}
    end
    _G.StaticPopupDialogs[dialogName] = {
      text = "Are you sure you want to clear all chats?\n\nThis will permanently delete all conversation history.",
      button1 = "Clear All",
      button2 = "Cancel",
      OnAccept = function()
        if options.onClearAllChats then
          options.onClearAllChats()
          options.refreshSelection({
            contacts = {},
            selectedContact = nil,
            conversation = nil,
            status = nil,
          }, true)
        end
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }

    clearAllChatsButton:SetScript("OnClick", function()
      _G.StaticPopup_Show(dialogName)
    end)
  end

  -- Tab switching: show one panel at a time, highlight active tab
  if #settingsTabs > 0 and #settingsPanels > 0 then
    local activeHighlight = Theme.COLORS.bg_contact_selected or { 0.16, 0.18, 0.28, 0.80 }
    local inactiveBg = Theme.COLORS.option_button_bg or { 0.14, 0.15, 0.20, 0.80 }

    local function selectTab(index)
      for i, panel in ipairs(settingsPanels) do
        if panel and panel.Hide and panel.Show then
          if i == index then
            panel:Show()
          else
            panel:Hide()
          end
        end
      end
      for i, tab in ipairs(settingsTabs) do
        if tab and tab.bg and tab.SetScript then
          local bg = tab.bg
          local isActive = i == index
          if isActive then
            bg:SetColorTexture(activeHighlight[1], activeHighlight[2], activeHighlight[3], activeHighlight[4] or 1)
          else
            bg:SetColorTexture(inactiveBg[1], inactiveBg[2], inactiveBg[3], inactiveBg[4] or 1)
          end
          tab:SetScript("OnEnter", function()
            bg:SetColorTexture(activeHighlight[1], activeHighlight[2], activeHighlight[3], activeHighlight[4] or 1)
          end)
          tab:SetScript("OnLeave", function()
            if isActive then
              bg:SetColorTexture(activeHighlight[1], activeHighlight[2], activeHighlight[3], activeHighlight[4] or 1)
            else
              bg:SetColorTexture(inactiveBg[1], inactiveBg[2], inactiveBg[3], inactiveBg[4] or 1)
            end
          end)
        end
      end
    end

    for i, tab in ipairs(settingsTabs) do
      if tab and tab.SetScript then
        local tabIndex = i
        tab:SetScript("OnClick", function()
          selectTab(tabIndex)
        end)
      end
    end

    -- Default: show first tab (General)
    selectTab(1)
  end
end

-- Wire OnShow, OnHide, OnEnter, OnLeave, OnUpdate, OnSizeChanged,
-- OnDragStart, OnDragStop on the main frame, plus OnMouseDown/OnMouseUp
-- on both resize handles.
--
-- refs:
--   frame, resizeGrip, contactsResizeHandle
--
-- options:
--   refreshWindowAlpha, layout, composer, contactsController, conversation,
--   buildState, trace, onPositionChanged, Theme
--   relayout (optional), refreshContactsLayout (optional),
--   getCursorX (optional), getFrameLeft (optional)
function WindowScripts.WireFrame(refs, options)
  local frame = refs.frame
  local resizeGrip = refs.resizeGrip
  local contactsResizeHandle = refs.contactsResizeHandle

  local alphaElapsed = 0
  local frameTheme = options.Theme or Theme
  local resizingContacts = false

  local function relayoutWindow(w, h, requestedContactsWidth, refreshContactsLayout)
    if options.relayout then
      options.relayout(w, h, requestedContactsWidth, refreshContactsLayout)
      return
    end

    if options.layout and options.layout.contactsPane then
      LayoutBuilder.Relayout(options.layout, w, h, requestedContactsWidth)
    end

    local contentW = w - frameTheme.CONTACTS_WIDTH - frameTheme.DIVIDER_THICKNESS
    if options.composer and options.composer.relayout then
      options.composer.relayout(contentW)
    end
    local contactsH = h - frameTheme.TOP_BAR_HEIGHT
    if options.contactsController and options.contactsController.fillViewport then
      options.contactsController.fillViewport(contactsH)
    end
    local threadH = contactsH - frameTheme.COMPOSER_HEIGHT - frameTheme.DIVIDER_THICKNESS
    if options.conversation then
      ConversationPane.Relayout(options.conversation, contentW, threadH)
    end
    if refreshContactsLayout and options.refreshContactsLayout then
      options.refreshContactsLayout()
    end
  end

  local function frameWidth()
    if frame and frame.GetWidth then
      return frame:GetWidth()
    end
    return frameTheme.WINDOW_WIDTH
  end

  local function frameHeight()
    if frame and frame.GetHeight then
      return frame:GetHeight()
    end
    return frameTheme.WINDOW_HEIGHT
  end

  local function getCursorX()
    if options.getCursorX then
      return options.getCursorX()
    end
    if type(_G.GetCursorPosition) ~= "function" then
      return nil
    end

    local cursorX = _G.GetCursorPosition()
    local scale = 1
    if frame and frame.GetEffectiveScale then
      local effectiveScale = frame:GetEffectiveScale()
      if type(effectiveScale) == "number" and effectiveScale > 0 then
        scale = effectiveScale
      end
    end
    return cursorX / scale
  end

  local function getFrameLeft()
    if options.getFrameLeft then
      return options.getFrameLeft()
    end
    if frame and frame.GetLeft then
      return frame:GetLeft()
    end
    return nil
  end

  local function setContactsHandleHighlight(isActive)
    if not contactsResizeHandle then
      return
    end

    local divider = options.layout and options.layout.contactsDivider or nil
    local dividerColor = frameTheme.COLORS and frameTheme.COLORS.divider or { 0.20, 0.22, 0.28, 1 }
    local hoverFillColor = frameTheme.COLORS and frameTheme.COLORS.bg_contact_hover or { 0.24, 0.28, 0.42, 1 }
    local outlineColor = dividerColor
    local dividerActiveAlpha = 0.62
    local hoverFillAlphaMultiplier = 0.18
    local outlineAlpha = 0.45

    if divider and divider.SetColorTexture then
      if isActive then
        divider:SetColorTexture(outlineColor[1], outlineColor[2], outlineColor[3], dividerActiveAlpha)
      else
        divider:SetColorTexture(dividerColor[1], dividerColor[2], dividerColor[3], dividerColor[4] or 1)
      end
    end

    if contactsResizeHandle.hoverBg and contactsResizeHandle.hoverBg.SetColorTexture then
      if isActive then
        contactsResizeHandle.hoverBg:SetColorTexture(
          hoverFillColor[1],
          hoverFillColor[2],
          hoverFillColor[3],
          (hoverFillColor[4] or 1) * hoverFillAlphaMultiplier
        )
      else
        contactsResizeHandle.hoverBg:SetColorTexture(0, 0, 0, 0)
      end
    end

    local outline = contactsResizeHandle.outline
    if outline then
      for _, edge in pairs(outline) do
        if edge and edge.SetColorTexture then
          if isActive then
            edge:SetColorTexture(outlineColor[1], outlineColor[2], outlineColor[3], outlineAlpha)
            if edge.Show then
              edge:Show()
            end
          else
            edge:SetColorTexture(0, 0, 0, 0)
            if edge.Hide then
              edge:Hide()
            end
          end
        end
      end
    end
  end

  local function updateContactsResizeFromCursor()
    if not resizingContacts then
      return
    end

    local cursorX = getCursorX()
    local frameLeft = getFrameLeft()
    if type(cursorX) ~= "number" or type(frameLeft) ~= "number" then
      return
    end

    relayoutWindow(frameWidth(), frameHeight(), cursorX - frameLeft, true)
  end

  local function stopContactsResize(button)
    if button ~= "LeftButton" or not resizingContacts then
      return
    end

    resizingContacts = false
    updateContactsResizeFromCursor()
    setContactsHandleHighlight(false)

    local nextState = options.buildState(frame)
    options.trace("contacts resize stop", nextState.contactsWidth)
    if options.onPositionChanged then
      options.onPositionChanged(nextState)
    end
  end

  if frame and frame.SetScript then
    frame:SetScript("OnShow", function()
      alphaElapsed = 0
      options.refreshWindowAlpha(true)
      if
        options.composerInput
        and options.getAutoFocusChatInput
        and options.getAutoFocusChatInput()
        and options.composerInput.SetFocus
      then
        options.composerInput:SetFocus()
      end
      options.trace("window shown")
    end)

    frame:SetScript("OnHide", function()
      alphaElapsed = 0
      resizingContacts = false
      setContactsHandleHighlight(false)
      options.trace("window hidden")
    end)

    frame:SetScript("OnEnter", function()
      options.refreshWindowAlpha(true)
    end)

    frame:SetScript("OnLeave", function()
      options.refreshWindowAlpha()
    end)

    frame:SetScript("OnUpdate", function(_, elapsed)
      alphaElapsed = alphaElapsed + (elapsed or 0)
      if alphaElapsed >= frameTheme.WINDOW_ALPHA_UPDATE_INTERVAL then
        alphaElapsed = 0
        options.refreshWindowAlpha()
      end
      updateContactsResizeFromCursor()
    end)

    frame:SetScript("OnSizeChanged", function(_self, w, h)
      relayoutWindow(w, h, nil, false)
    end)

    frame:SetScript("OnDragStart", function(self)
      if self.IsMovable == nil or self:IsMovable() then
        self:StartMoving()
        options.trace("window drag start")
      end
    end)

    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local nextState = options.buildState(self)
      options.trace("window drag stop", nextState.anchorPoint, nextState.x, nextState.y)
      if options.onPositionChanged then
        options.onPositionChanged(nextState)
      end
    end)

    local previousFrameMouseUp = frame.GetScript and frame:GetScript("OnMouseUp")
    frame:SetScript("OnMouseUp", function(self, button)
      if previousFrameMouseUp then
        previousFrameMouseUp(self, button)
      end
      stopContactsResize(button)
    end)
  end

  if resizeGrip and resizeGrip.SetScript then
    resizeGrip:SetScript("OnMouseDown", function(_self, button)
      if button == "LeftButton" then
        frame:StartSizing("BOTTOMRIGHT")
        options.trace("window resize start")
      end
    end)

    resizeGrip:SetScript("OnMouseUp", function(_self, button)
      if button == "LeftButton" then
        frame:StopMovingOrSizing()
        local nextState = options.buildState(frame)
        options.trace("window resize stop", nextState.width, nextState.height)
        if options.onPositionChanged then
          options.onPositionChanged(nextState)
        end
      end
    end)
  end

  if contactsResizeHandle and contactsResizeHandle.SetScript then
    contactsResizeHandle:SetScript("OnEnter", function()
      setContactsHandleHighlight(true)
    end)

    contactsResizeHandle:SetScript("OnLeave", function()
      if not resizingContacts then
        setContactsHandleHighlight(false)
      end
    end)

    contactsResizeHandle:SetScript("OnMouseDown", function(_self, button)
      if button == "LeftButton" then
        resizingContacts = true
        setContactsHandleHighlight(true)
        updateContactsResizeFromCursor()
        options.trace("contacts resize start")
      end
    end)

    contactsResizeHandle:SetScript("OnMouseUp", function(_self, button)
      stopContactsResize(button)
    end)
  end
end

ns.MessengerWindowWindowScripts = WindowScripts

return WindowScripts
