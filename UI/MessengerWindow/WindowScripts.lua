local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")

local WindowScripts = {}

local RESIZE_PREVIEW_FILL_ALPHA = 0.20
local RESIZE_PREVIEW_BORDER_ALPHA = 0.85
local RESIZE_DRAG_FRAME_ALPHA = 0.08

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
--   getCursorX/getCursorY (optional), getFrameLeft/getFrameTop (optional)
function WindowScripts.WireFrame(refs, options)
  local frame = refs.frame
  local resizeGrip = refs.resizeGrip
  local contactsResizeHandle = refs.contactsResizeHandle

  local alphaElapsed = 0
  local frameTheme = options.Theme or Theme
  local resizingContacts = false
  local resizingWindow = false
  local pendingWindowWidth = nil
  local pendingWindowHeight = nil
  local suppressSizeChangedRelayout = false
  local preResizeAlpha = nil

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

  local function getCursorY()
    if options.getCursorY then
      return options.getCursorY()
    end
    if type(_G.GetCursorPosition) ~= "function" then
      return nil
    end

    local _, cursorY = _G.GetCursorPosition()
    local scale = 1
    if frame and frame.GetEffectiveScale then
      local effectiveScale = frame:GetEffectiveScale()
      if type(effectiveScale) == "number" and effectiveScale > 0 then
        scale = effectiveScale
      end
    end
    return cursorY / scale
  end

  local function getFrameTop()
    if options.getFrameTop then
      return options.getFrameTop()
    end
    if frame and frame.GetTop then
      return frame:GetTop()
    end
    return nil
  end

  local function getFrameParent()
    if options.getFrameParent then
      return options.getFrameParent()
    end
    if frame and frame.parent then
      return frame.parent
    end
    if _G.UIParent then
      return _G.UIParent
    end
    return nil
  end

  local function resolveResizeBounds()
    local minWidth, minHeight = frameTheme.WINDOW_MIN_WIDTH or 640, frameTheme.WINDOW_MIN_HEIGHT or 420
    local maxWidth, maxHeight = nil, nil

    if frame and type(frame.resizeBounds) == "table" then
      minWidth = frame.resizeBounds[1] or minWidth
      minHeight = frame.resizeBounds[2] or minHeight
      maxWidth = frame.resizeBounds[3]
      maxHeight = frame.resizeBounds[4]
    elseif frame and type(frame.minResize) == "table" then
      minWidth = frame.minResize[1] or minWidth
      minHeight = frame.minResize[2] or minHeight
    end

    return minWidth, minHeight, maxWidth, maxHeight
  end

  local function clampWindowSize(width, height)
    local minWidth, minHeight, maxWidth, maxHeight = resolveResizeBounds()
    local clampedWidth = math.max(minWidth, width or minWidth)
    local clampedHeight = math.max(minHeight, height or minHeight)
    if type(maxWidth) == "number" and maxWidth > 0 then
      clampedWidth = math.min(clampedWidth, maxWidth)
    end
    if type(maxHeight) == "number" and maxHeight > 0 then
      clampedHeight = math.min(clampedHeight, maxHeight)
    end
    return clampedWidth, clampedHeight
  end

  local windowResizePreviewHost = getFrameParent() or frame
  local windowResizePreview = nil
  if windowResizePreviewHost and windowResizePreviewHost.CreateTexture then
    local dividerColor = frameTheme.COLORS and frameTheme.COLORS.divider or { 0.20, 0.22, 0.28, 1 }
    local fillColor = frameTheme.COLORS and frameTheme.COLORS.bg_secondary or { 0.10, 0.10, 0.14, 1 }

    windowResizePreview = {
      bg = windowResizePreviewHost:CreateTexture(nil, "OVERLAY"),
      top = windowResizePreviewHost:CreateTexture(nil, "OVERLAY"),
      bottom = windowResizePreviewHost:CreateTexture(nil, "OVERLAY"),
      left = windowResizePreviewHost:CreateTexture(nil, "OVERLAY"),
      right = windowResizePreviewHost:CreateTexture(nil, "OVERLAY"),
    }

    windowResizePreview.bg:SetColorTexture(fillColor[1], fillColor[2], fillColor[3], RESIZE_PREVIEW_FILL_ALPHA)
    windowResizePreview.top:SetColorTexture(
      dividerColor[1],
      dividerColor[2],
      dividerColor[3],
      RESIZE_PREVIEW_BORDER_ALPHA
    )
    windowResizePreview.bottom:SetColorTexture(
      dividerColor[1],
      dividerColor[2],
      dividerColor[3],
      RESIZE_PREVIEW_BORDER_ALPHA
    )
    windowResizePreview.left:SetColorTexture(
      dividerColor[1],
      dividerColor[2],
      dividerColor[3],
      RESIZE_PREVIEW_BORDER_ALPHA
    )
    windowResizePreview.right:SetColorTexture(
      dividerColor[1],
      dividerColor[2],
      dividerColor[3],
      RESIZE_PREVIEW_BORDER_ALPHA
    )

    if resizeGrip then
      resizeGrip.preview = windowResizePreview
    end
    for _, texture in pairs(windowResizePreview) do
      if texture.Hide then
        texture:Hide()
      end
    end
  end

  local function setWindowResizePreviewShown(isShown)
    if not windowResizePreview then
      return
    end
    for _, texture in pairs(windowResizePreview) do
      if isShown then
        if texture.Show then
          texture:Show()
        end
      elseif texture.Hide then
        texture:Hide()
      end
    end
  end

  local function updateWindowResizePreview(width, height)
    if not windowResizePreview then
      return
    end

    local previewLeft = getFrameLeft()
    local previewTop = getFrameTop()
    if type(previewLeft) ~= "number" or type(previewTop) ~= "number" then
      return
    end

    local previewWidth = math.max(1, width or frameWidth())
    local previewHeight = math.max(1, height or frameHeight())

    if windowResizePreview.bg.ClearAllPoints then
      windowResizePreview.bg:ClearAllPoints()
    end
    windowResizePreview.bg:SetPoint("TOPLEFT", windowResizePreviewHost, "BOTTOMLEFT", previewLeft, previewTop)
    windowResizePreview.bg:SetSize(previewWidth, previewHeight)

    if windowResizePreview.top.ClearAllPoints then
      windowResizePreview.top:ClearAllPoints()
    end
    windowResizePreview.top:SetPoint("TOPLEFT", windowResizePreviewHost, "BOTTOMLEFT", previewLeft, previewTop)
    windowResizePreview.top:SetPoint(
      "TOPRIGHT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft + previewWidth,
      previewTop
    )
    windowResizePreview.top:SetHeight(1)

    if windowResizePreview.bottom.ClearAllPoints then
      windowResizePreview.bottom:ClearAllPoints()
    end
    windowResizePreview.bottom:SetPoint(
      "BOTTOMLEFT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft,
      previewTop - previewHeight
    )
    windowResizePreview.bottom:SetPoint(
      "BOTTOMRIGHT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft + previewWidth,
      previewTop - previewHeight
    )
    windowResizePreview.bottom:SetHeight(1)

    if windowResizePreview.left.ClearAllPoints then
      windowResizePreview.left:ClearAllPoints()
    end
    windowResizePreview.left:SetPoint("TOPLEFT", windowResizePreviewHost, "BOTTOMLEFT", previewLeft, previewTop)
    windowResizePreview.left:SetPoint(
      "BOTTOMLEFT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft,
      previewTop - previewHeight
    )
    windowResizePreview.left:SetWidth(1)

    if windowResizePreview.right.ClearAllPoints then
      windowResizePreview.right:ClearAllPoints()
    end
    windowResizePreview.right:SetPoint(
      "TOPRIGHT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft + previewWidth,
      previewTop
    )
    windowResizePreview.right:SetPoint(
      "BOTTOMRIGHT",
      windowResizePreviewHost,
      "BOTTOMLEFT",
      previewLeft + previewWidth,
      previewTop - previewHeight
    )
    windowResizePreview.right:SetWidth(1)

    setWindowResizePreviewShown(true)
  end

  local function updateWindowResizeFromCursor()
    if not resizingWindow then
      return
    end

    local cursorX = getCursorX()
    local cursorY = getCursorY()
    local frameLeft = getFrameLeft()
    local frameTop = getFrameTop()
    if
      type(cursorX) ~= "number"
      or type(cursorY) ~= "number"
      or type(frameLeft) ~= "number"
      or type(frameTop) ~= "number"
    then
      return
    end

    local nextWidth, nextHeight = clampWindowSize(cursorX - frameLeft, frameTop - cursorY)
    pendingWindowWidth = nextWidth
    pendingWindowHeight = nextHeight
    updateWindowResizePreview(nextWidth, nextHeight)
  end

  local function stopWindowResize(button)
    if button ~= "LeftButton" or not resizingWindow then
      return
    end

    resizingWindow = false
    setWindowResizePreviewShown(false)
    if frame and frame.SetAlpha then
      frame:SetAlpha(preResizeAlpha or 1)
      preResizeAlpha = nil
    end

    local nextWidth, nextHeight =
      clampWindowSize(pendingWindowWidth or frameWidth(), pendingWindowHeight or frameHeight())
    pendingWindowWidth = nil
    pendingWindowHeight = nil

    local stableLeft = getFrameLeft()
    local stableTop = getFrameTop()

    suppressSizeChangedRelayout = true
    if frame and frame.SetSize then
      frame:SetSize(nextWidth, nextHeight)
    end
    if
      frame
      and frame.ClearAllPoints
      and frame.SetPoint
      and type(stableLeft) == "number"
      and type(stableTop) == "number"
    then
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", getFrameParent(), "BOTTOMLEFT", stableLeft, stableTop)
    end
    suppressSizeChangedRelayout = false
    relayoutWindow(nextWidth, nextHeight, nil, false)

    local nextState = options.buildState(frame)
    options.trace("window resize stop", nextState.width, nextState.height)
    if options.onPositionChanged then
      options.onPositionChanged(nextState)
    end
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
      resizingWindow = false
      pendingWindowWidth = nil
      pendingWindowHeight = nil
      preResizeAlpha = nil
      setContactsHandleHighlight(false)
      setWindowResizePreviewShown(false)
      options.trace("window hidden")
    end)

    frame:SetScript("OnEnter", function()
      if resizingWindow then
        return
      end
      options.refreshWindowAlpha(true)
    end)

    frame:SetScript("OnLeave", function()
      if resizingWindow then
        return
      end
      options.refreshWindowAlpha()
    end)

    frame:SetScript("OnUpdate", function(_, elapsed)
      alphaElapsed = alphaElapsed + (elapsed or 0)
      if not resizingWindow and alphaElapsed >= frameTheme.WINDOW_ALPHA_UPDATE_INTERVAL then
        alphaElapsed = 0
        options.refreshWindowAlpha()
      end
      updateContactsResizeFromCursor()
      updateWindowResizeFromCursor()
    end)

    frame:SetScript("OnSizeChanged", function(_self, w, h)
      if suppressSizeChangedRelayout then
        return
      end
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
      stopWindowResize(button)
      stopContactsResize(button)
    end)
  end

  if resizeGrip and resizeGrip.SetScript then
    resizeGrip:SetScript("OnMouseDown", function(_self, button)
      if button == "LeftButton" then
        resizingWindow = true
        pendingWindowWidth, pendingWindowHeight = clampWindowSize(frameWidth(), frameHeight())
        if frame and frame.GetAlpha then
          preResizeAlpha = frame:GetAlpha()
        else
          preResizeAlpha = 1
        end
        if frame and frame.SetAlpha then
          frame:SetAlpha(RESIZE_DRAG_FRAME_ALPHA)
        end
        updateWindowResizeFromCursor()
        updateWindowResizePreview(pendingWindowWidth, pendingWindowHeight)
        options.trace("window resize start")
      end
    end)

    resizeGrip:SetScript("OnMouseUp", function(_self, button)
      stopWindowResize(button)
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
