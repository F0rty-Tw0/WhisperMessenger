local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local PreviewMetrics = ns.ToggleIconPreviewMetrics or require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local PreviewAutoDismiss = ns.ToggleIconPreviewAutoDismiss or require("WhisperMessenger.UI.ToggleIcon.PreviewAutoDismiss")
local PreviewLinks = ns.ToggleIconPreviewLinks or require("WhisperMessenger.UI.ToggleIcon.PreviewLinks")
local PreviewReplyHold = ns.ToggleIconPreviewReplyHold or require("WhisperMessenger.UI.ToggleIcon.PreviewReplyHold")
local PreviewCard = ns.ToggleIconPreviewCard or require("WhisperMessenger.UI.ToggleIcon.PreviewCard")
local applyClassColor = UIHelpers.applyClassColor
local setTextColor = UIHelpers.setTextColor

local IncomingPreview = {}

function IncomingPreview.Create(factory, frame, options)
  options = options or {}

  local theme = options.theme or Theme
  local card = PreviewCard.Create(factory, frame, theme, options.getPreviewPosition)
  local previewFrame, previewBackground = card.frame, card.background
  local positioner = card.positioner
  local previewClassIconFrame, previewClassIcon = card.classIconFrame, card.classIcon
  local previewSenderLabel, previewMessageLabel = card.senderLabel, card.messageLabel
  local dismiss = card.dismiss
  local detailRow = card.detailRow

  local autoDismiss
  local hold
  local lastPreviewSenderName = nil
  local lastPreviewMessageText = nil
  local lastPreviewClassTag = nil
  -- A preview another addon put here; its callbacks come pre-wrapped.
  local externalEntry = nil
  local suppressed = false

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

  -- Opens the whisper on the card; true when the chat opened. The owner
  -- acknowledges the whisper, and the refresh then clears the preview.
  local function openOwnPreview()
    local handled, opened = hold.onOpen()
    if handled then
      return opened
    end
    return options.onOpenPreview ~= nil and options.onOpenPreview() == true
  end

  -- The button click: only a whisper card on screen opens, not another addon's.
  local function openShownPreview()
    if externalEntry ~= nil or lastPreviewSenderName == nil or not previewFrame:IsVisible() then
      return false
    end
    return openOwnPreview()
  end

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
      elseif button == "LeftButton" then
        openOwnPreview()
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
    -- Docked: the card would cover the title bar, and closing the window
    -- acknowledges the whispers, so the card never needs to show.
    if not hasMessage or suppressed then
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
    if suppressed then
      return
    elseif previewFrame:IsVisible() then
      entry.onShown()
    else
      previewFrame:Show()
    end
    notifyExternalChanged(true)
  end

  -- The button sits on the open window, where the card would cover the title
  -- bar. Another addon's card waits and comes back once the button is home.
  local function setSuppressed(on)
    suppressed = on == true
    if suppressed and externalEntry == nil then
      clearIncomingPreview()
    elseif externalEntry ~= nil then
      previewFrame:SetShown(not suppressed)
      notifyExternalChanged(true)
    end
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
    openShownPreview = openShownPreview,
    setSuppressed = setSuppressed,
    applyPreviewPosition = positioner.apply,
    applyTheme = applyTheme,
    replyHold = hold,
  }
end

ns.ToggleIconIncomingPreview = IncomingPreview

return IncomingPreview
