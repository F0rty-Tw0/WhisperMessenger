local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local PreviewMetrics = ns.ToggleIconPreviewMetrics or require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local PreviewAutoDismiss = ns.ToggleIconPreviewAutoDismiss or require("WhisperMessenger.UI.ToggleIcon.PreviewAutoDismiss")
local PreviewChrome = ns.ToggleIconPreviewChrome or require("WhisperMessenger.UI.ToggleIcon.PreviewChrome")
local PreviewLinks = ns.ToggleIconPreviewLinks or require("WhisperMessenger.UI.ToggleIcon.PreviewLinks")
local PreviewDetailRow = ns.ToggleIconPreviewDetailRow or require("WhisperMessenger.UI.ToggleIcon.PreviewDetailRow")
local PreviewDismissButton = ns.ToggleIconPreviewDismissButton or require("WhisperMessenger.UI.ToggleIcon.PreviewDismissButton")
local PreviewReplyHold = ns.ToggleIconPreviewReplyHold or require("WhisperMessenger.UI.ToggleIcon.PreviewReplyHold")
local applyClassColor = UIHelpers.applyClassColor
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local IncomingPreview = {}

function IncomingPreview.Create(factory, frame, options)
  options = options or {}

  local theme = options.theme or Theme
  local previewFrame, previewBackground = PreviewChrome.Create(factory, frame)
  previewFrame:SetSize(PreviewMetrics.MAX_WIDTH, PreviewMetrics.HEIGHT)

  local positioner = PreviewMetrics.NewPositioner(previewFrame, frame, options.getPreviewPosition)
  positioner.apply(positioner.resolve())
  if previewFrame.SetFrameLevel then
    previewFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
  end
  -- The minimap icon reparents this frame to UIParent, which would otherwise drop it to MEDIUM strata.
  if previewFrame.SetFrameStrata then
    previewFrame:SetFrameStrata("HIGH")
  end
  if previewFrame.EnableMouse then
    previewFrame:EnableMouse(true)
  end

  local previewClassIconResult = UIHelpers.createCircularIcon(factory, previewFrame, PreviewMetrics.CLASS_ICON_SIZE)
  local previewClassIconFrame = previewClassIconResult.frame
  local previewClassIcon = previewClassIconResult.texture
  previewClassIconFrame:SetPoint("LEFT", previewFrame, "LEFT", PreviewMetrics.LEFT_PAD, 0)
  previewClassIconFrame:Hide()

  local dismiss = PreviewDismissButton.Create(factory, previewFrame, theme)

  local senderLeft = PreviewMetrics.LEFT_PAD + PreviewMetrics.CLASS_ICON_SIZE + PreviewMetrics.ICON_GAP
  local previewSenderLabel = previewFrame:CreateFontString(nil, "OVERLAY")
  -- Font objects only: a raw SetFont on a FontString overrides the engine's
  -- Unicode glyph-fallback chain and blanks Cyrillic/Greek characters.
  setFontObject(previewSenderLabel, theme.FONTS.message_text)
  previewSenderLabel:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", senderLeft, PreviewMetrics.SENDER_TOP_OFFSET)
  PreviewChrome.SingleLine(previewSenderLabel)

  local previewMessageLabel = previewFrame:CreateFontString(nil, "OVERLAY")
  setFontObject(previewMessageLabel, theme.FONTS.message_text)
  previewMessageLabel:SetPoint("TOPLEFT", previewSenderLabel, "BOTTOMLEFT", 0, PreviewMetrics.MESSAGE_GAP)
  PreviewChrome.SingleLine(previewMessageLabel)
  local detailRow = PreviewDetailRow.Create(previewFrame, previewMessageLabel, theme.FONTS.message_text)
  previewFrame:Hide()

  local autoDismiss
  local hold
  local lastPreviewSenderName = nil
  local lastPreviewMessageText = nil
  local lastPreviewClassTag = nil
  -- A preview another addon put here; its callbacks come pre-wrapped.
  local externalEntry = nil

  local function notifyExternalChanged(changed)
    if changed and options.onExternalChanged then
      options.onExternalChanged()
    end
  end

  local function clearIncomingPreview()
    hold.onCleared()
    local hadExternal = externalEntry ~= nil
    autoDismiss.cancel()
    lastPreviewSenderName, lastPreviewMessageText, lastPreviewClassTag = nil, nil, nil
    externalEntry = nil
    previewSenderLabel:SetText("")
    previewMessageLabel:SetText("")
    detailRow.render(nil)
    previewClassIcon:SetTexture(nil)
    previewClassIconFrame:Hide()
    previewFrame:Hide()
    notifyExternalChanged(hadExternal)
  end

  local function triggerDismiss()
    clearIncomingPreview()
    if options.onDismissPreview then
      options.onDismissPreview()
    end
  end

  -- The x and right-click: an external preview only tells its owner, so
  -- WM's own latest whisper is never acknowledged by it.
  local function dismissCurrent()
    if hold.onDismiss() then
      return
    end
    local current = externalEntry
    if current == nil then
      triggerDismiss()
      return
    end
    clearIncomingPreview()
    current.onDismiss()
  end

  autoDismiss = PreviewAutoDismiss.New({
    getSeconds = options.getPreviewAutoDismissSeconds,
    isShown = function()
      return not previewFrame.IsShown or previewFrame:IsShown()
    end,
    onExpire = triggerDismiss,
  })
  hold = PreviewReplyHold.Create(factory, previewFrame, {
    theme = theme,
    quickReply = options.quickReply,
    autoDismiss = autoDismiss,
    hideCard = clearIncomingPreview,
  })

  if dismiss.button.SetScript then
    dismiss.button:SetScript("OnClick", dismissCurrent)
  end

  if previewFrame.SetScript then
    PreviewLinks.SetMouseUp(previewFrame, function(_self, button)
      local current = externalEntry
      if button == "RightButton" then
        dismissCurrent()
      elseif button == "LeftButton" and current ~= nil then
        current.onClick()
        -- onClick may have put up another preview; keep that one.
        if externalEntry == current then
          clearIncomingPreview()
        end
      elseif button == "LeftButton" and hold.onOpen() then
        return
      elseif button == "LeftButton" and options.onOpenPreview then
        -- The owner acknowledges the whisper; the refresh then clears the preview.
        options.onOpenPreview()
      end
    end)
    previewFrame:SetScript("OnShow", function()
      if externalEntry ~= nil then
        externalEntry.onShown()
      end
    end)
  end

  local function paintSenderLabel(classTag)
    applyClassColor(previewSenderLabel, classTag, theme.COLORS.text_primary)
  end

  local function renderContent(senderName, messageText, classTag, detail)
    previewSenderLabel:SetText(type(senderName) == "string" and senderName or "")
    paintSenderLabel(classTag)
    previewMessageLabel:SetText(ReactionAssets.FormatTextForDisplay(messageText))
    detailRow.render(detail)

    local classIconPath = theme.ClassIcon(classTag)
    if classIconPath then
      previewClassIcon:SetTexture(classIconPath)
    else
      previewClassIcon:SetTexture(theme.TEXTURES.bnet_icon)
    end
    previewClassIconFrame:Show()

    positioner.apply(positioner.resolve())
  end

  -- The create-time anchor above is the plain card's.
  local classIconAnchor = false
  local function fitWidth()
    local replyHeight = hold.rowHeight()
    PreviewMetrics.ResizeToContent(previewFrame, previewSenderLabel, previewMessageLabel, detailRow.shownLabel(), replyHeight)
    classIconAnchor = PreviewMetrics.AnchorClassIcon(previewClassIconFrame, previewFrame, replyHeight, classIconAnchor)
  end

  -- meta (optional) = { conversationKey, sentAt, channel } for the reply row.
  local function setIncomingPreview(senderName, messageText, classTag, meta)
    local hadExternal = externalEntry ~= nil
    local hasMessage = type(messageText) == "string" and messageText ~= ""
    if hold.route(hasMessage and meta or nil, false) == "ignore" then
      return
    end
    if not hasMessage then
      clearIncomingPreview()
      return
    end
    externalEntry = nil

    local isSameContent = senderName == lastPreviewSenderName and messageText == lastPreviewMessageText and classTag == lastPreviewClassTag

    renderContent(senderName, messageText, classTag)
    previewFrame:Show()

    if not isSameContent then
      lastPreviewSenderName = senderName
      lastPreviewMessageText = messageText
      lastPreviewClassTag = classTag
      autoDismiss.schedule()
    end
    hold.onApplied(meta)
    fitWidth()
    notifyExternalChanged(hadExternal)
  end

  -- No auto-dismiss: the owner decides when its preview goes away.
  local function setExternalPreview(entry)
    if entry == nil then
      if externalEntry ~= nil then
        clearIncomingPreview()
      end
      return
    end
    if entry == externalEntry then
      return
    end
    if hold.route(nil, true) == "ignore" then
      return
    end
    hold.onCleared()
    autoDismiss.cancel()
    lastPreviewSenderName, lastPreviewMessageText, lastPreviewClassTag = nil, nil, nil
    externalEntry = entry
    renderContent(entry.sender, entry.text, entry.classTag, entry.detail)
    fitWidth()
    if previewFrame:IsVisible() then
      entry.onShown()
    else
      previewFrame:Show()
    end
    notifyExternalChanged(true)
  end

  local function isExternalShown()
    return externalEntry ~= nil and previewFrame:IsVisible()
  end

  local function applyTheme(activeTheme)
    theme = activeTheme or theme
    if previewBackground and previewBackground.setColor then
      previewBackground.setColor(theme.COLORS.bg_secondary or theme.COLORS.bg_primary)
    end
    paintSenderLabel(externalEntry and externalEntry.classTag or lastPreviewClassTag)
    setTextColor(previewMessageLabel, theme.COLORS.text_secondary)
    setTextColor(detailRow.label, theme.COLORS.text_secondary)
    dismiss.applyTheme(theme)
    hold.applyTheme(theme)
  end

  return {
    frame = previewFrame,
    senderLabel = previewSenderLabel,
    messageLabel = previewMessageLabel,
    detailLabel = detailRow.label,
    dismissButton = dismiss.button,
    dismissLabel = dismiss.label,
    classIcon = previewClassIcon,
    classIconFrame = previewClassIconFrame,
    setIncomingPreview = setIncomingPreview,
    setExternalPreview = setExternalPreview,
    isExternalShown = isExternalShown,
    applyPreviewPosition = positioner.apply,
    applyTheme = applyTheme,
    replyHold = hold,
  }
end

ns.ToggleIconIncomingPreview = IncomingPreview

return IncomingPreview
