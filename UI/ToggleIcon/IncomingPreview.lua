local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local CloseGlyphButton = ns.CloseGlyphButton or require("WhisperMessenger.UI.Shared.CloseGlyphButton")
local PreviewMetrics = ns.ToggleIconPreviewMetrics or require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local PreviewAutoDismiss = ns.ToggleIconPreviewAutoDismiss or require("WhisperMessenger.UI.ToggleIcon.PreviewAutoDismiss")
local PreviewChrome = ns.ToggleIconPreviewChrome or require("WhisperMessenger.UI.ToggleIcon.PreviewChrome")
local PreviewLinks = ns.ToggleIconPreviewLinks or require("WhisperMessenger.UI.ToggleIcon.PreviewLinks")
local PreviewDetailRow = ns.ToggleIconPreviewDetailRow or require("WhisperMessenger.UI.ToggleIcon.PreviewDetailRow")
local applyClassColor = UIHelpers.applyClassColor
local applyVertexColor = UIHelpers.applyVertexColor
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local DISMISS_COLOR_HOVER = CloseGlyphButton.DANGER_HOVER
local DISMISS_BG_HOVER = { 0.85, 0.15, 0.15, 0.35 }

local IncomingPreview = {}

function IncomingPreview.Create(factory, frame, options)
  options = options or {}

  local theme = options.theme or Theme
  local previewFrame, previewBackground = PreviewChrome.Create(factory, frame)
  previewFrame:SetSize(PreviewMetrics.MAX_WIDTH, PreviewMetrics.HEIGHT)

  local currentPreviewPosition = "right"
  local function applyPreviewPosition(position)
    local nextPosition = (type(position) == "string" and position ~= "") and position or "right"
    currentPreviewPosition = nextPosition
    local anchor = PreviewMetrics.ResolveAnchor(nextPosition)
    if previewFrame.ClearAllPoints then
      previewFrame:ClearAllPoints()
    end
    if previewFrame.SetPoint then
      previewFrame:SetPoint(anchor.selfPoint, frame, anchor.target, anchor.x, anchor.y)
    end
  end

  local function resolvePreviewPosition()
    if type(options.getPreviewPosition) == "function" then
      local ok, value = pcall(options.getPreviewPosition)
      if ok and type(value) == "string" and value ~= "" then
        return value
      end
    end
    return currentPreviewPosition
  end

  applyPreviewPosition(resolvePreviewPosition())
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

  local previewDismissButton = factory.CreateFrame("Button", nil, previewFrame)
  previewDismissButton:SetSize(PreviewMetrics.DISMISS_SIZE, PreviewMetrics.DISMISS_SIZE)
  previewDismissButton:SetPoint("TOPRIGHT", previewFrame, "TOPRIGHT", -PreviewMetrics.DISMISS_INSET, -PreviewMetrics.DISMISS_INSET)
  if previewDismissButton.EnableMouse then
    previewDismissButton:EnableMouse(true)
  end
  local previewDismissBg = previewDismissButton:CreateTexture(nil, "BACKGROUND")
  previewDismissBg:SetAllPoints(previewDismissButton)
  applyVertexColor(previewDismissBg, { 0, 0, 0, 0 })
  local previewDismissLabel = previewDismissButton:CreateFontString(nil, "OVERLAY")
  setFontObject(previewDismissLabel, theme.FONTS.close_glyph or theme.FONTS.header_name)
  previewDismissLabel:SetPoint("CENTER", previewDismissButton, "CENTER", 0, 0)
  previewDismissLabel:SetText("×")
  -- Neutral at rest; red only on hover so the toast does not shout.
  setTextColor(previewDismissLabel, theme.COLORS.text_secondary)

  local senderLeft = PreviewMetrics.LEFT_PAD + PreviewMetrics.CLASS_ICON_SIZE + PreviewMetrics.ICON_GAP
  local previewSenderLabel = previewFrame:CreateFontString(nil, "OVERLAY")
  -- Font objects only: a raw SetFont on a FontString overrides the engine's
  -- Unicode glyph-fallback chain and blanks Cyrillic/Greek characters.
  setFontObject(previewSenderLabel, theme.FONTS.header_name or theme.FONTS.message_text)
  previewSenderLabel:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", senderLeft, PreviewMetrics.SENDER_TOP_OFFSET)
  PreviewChrome.SingleLine(previewSenderLabel)

  local previewMessageLabel = previewFrame:CreateFontString(nil, "OVERLAY")
  setFontObject(previewMessageLabel, theme.FONTS.message_text)
  previewMessageLabel:SetPoint("TOPLEFT", previewSenderLabel, "BOTTOMLEFT", 0, PreviewMetrics.MESSAGE_GAP)
  PreviewChrome.SingleLine(previewMessageLabel)
  local detailRow = PreviewDetailRow.Create(previewFrame, previewMessageLabel, theme.FONTS.message_text)
  previewFrame:Hide()

  local autoDismiss
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

  if previewDismissButton.SetScript then
    previewDismissButton:SetScript("OnClick", dismissCurrent)
    previewDismissButton:SetScript("OnEnter", function()
      setTextColor(previewDismissLabel, DISMISS_COLOR_HOVER)
      applyVertexColor(previewDismissBg, DISMISS_BG_HOVER)
    end)
    previewDismissButton:SetScript("OnLeave", function()
      setTextColor(previewDismissLabel, theme.COLORS.text_secondary)
      applyVertexColor(previewDismissBg, { 0, 0, 0, 0 })
    end)
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

    applyPreviewPosition(resolvePreviewPosition())
  end

  local function fitWidth()
    PreviewMetrics.ResizeToContent(previewFrame, previewSenderLabel, previewMessageLabel, detailRow.shownLabel())
  end

  local function setIncomingPreview(senderName, messageText, classTag)
    local hadExternal = externalEntry ~= nil
    local hasMessage = type(messageText) == "string" and messageText ~= ""
    if not hasMessage then
      clearIncomingPreview()
      return
    end
    externalEntry = nil

    local isSameContent = senderName == lastPreviewSenderName and messageText == lastPreviewMessageText and classTag == lastPreviewClassTag

    renderContent(senderName, messageText, classTag)
    previewFrame:Show()
    fitWidth()

    if not isSameContent then
      lastPreviewSenderName = senderName
      lastPreviewMessageText = messageText
      lastPreviewClassTag = classTag
      autoDismiss.schedule()
    end
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
    setTextColor(previewDismissLabel, theme.COLORS.text_secondary)
  end

  return {
    frame = previewFrame,
    senderLabel = previewSenderLabel,
    messageLabel = previewMessageLabel,
    detailLabel = detailRow.label,
    dismissButton = previewDismissButton,
    dismissLabel = previewDismissLabel,
    classIcon = previewClassIcon,
    classIconFrame = previewClassIconFrame,
    setIncomingPreview = setIncomingPreview,
    setExternalPreview = setExternalPreview,
    isExternalShown = isExternalShown,
    applyPreviewPosition = applyPreviewPosition,
    applyTheme = applyTheme,
  }
end

ns.ToggleIconIncomingPreview = IncomingPreview

return IncomingPreview
