local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor
local createRoundedBackground = UIHelpers.createRoundedBackground
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local PREVIEW_GAP = 8
local PREVIEW_MAX_WIDTH = 200
local PREVIEW_MIN_WIDTH = 60
local PREVIEW_HEIGHT = 42
local PREVIEW_CLASS_ICON_SIZE = 18
local PREVIEW_DISMISS_SIZE = 16
local PREVIEW_LEFT_PAD = 6
local PREVIEW_RIGHT_PAD = 6
local PREVIEW_ICON_GAP = 6
local PREVIEW_DISMISS_GAP = 4
local PREVIEW_SENDER_TOP_OFFSET = -8
local PREVIEW_MESSAGE_GAP = -1
local DISMISS_COLOR = { 0.85, 0.15, 0.15, 0.95 }
local DISMISS_COLOR_HOVER = { 1.0, 0.35, 0.35, 1.0 }
local DISMISS_BG_HOVER = { 0.85, 0.15, 0.15, 0.35 }

local PREVIEW_ANCHORS = {
  right = { selfPoint = "LEFT", target = "RIGHT", x = PREVIEW_GAP, y = 0 },
  left = { selfPoint = "RIGHT", target = "LEFT", x = -PREVIEW_GAP, y = 0 },
  top = { selfPoint = "BOTTOM", target = "TOP", x = 0, y = PREVIEW_GAP },
  above = { selfPoint = "BOTTOM", target = "TOP", x = 0, y = PREVIEW_GAP },
  bottom = { selfPoint = "TOP", target = "BOTTOM", x = 0, y = -PREVIEW_GAP },
  below = { selfPoint = "TOP", target = "BOTTOM", x = 0, y = -PREVIEW_GAP },
}

local function resolvePreviewAnchor(position)
  return PREVIEW_ANCHORS[position] or PREVIEW_ANCHORS.right
end

local IncomingPreview = {}

function IncomingPreview.Create(factory, frame, options)
  options = options or {}

  local theme = options.theme or Theme
  local previewFrame = factory.CreateFrame("Frame", nil, frame)
  previewFrame:SetSize(PREVIEW_MAX_WIDTH, PREVIEW_HEIGHT)

  local currentPreviewPosition = "right"
  local function applyPreviewPosition(position)
    local nextPosition = (type(position) == "string" and position ~= "") and position or "right"
    currentPreviewPosition = nextPosition
    local anchor = resolvePreviewAnchor(nextPosition)
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
  if previewFrame.EnableMouse then
    previewFrame:EnableMouse(true)
  end

  local previewBackground = createRoundedBackground(previewFrame, 4)

  local previewClassIconResult = UIHelpers.createCircularIcon(factory, previewFrame, PREVIEW_CLASS_ICON_SIZE)
  local previewClassIconFrame = previewClassIconResult.frame
  local previewClassIcon = previewClassIconResult.texture
  previewClassIconFrame:SetPoint("LEFT", previewFrame, "LEFT", PREVIEW_LEFT_PAD, 0)
  previewClassIconFrame:Hide()

  local previewDismissButton = factory.CreateFrame("Button", nil, previewFrame)
  previewDismissButton:SetSize(PREVIEW_DISMISS_SIZE, PREVIEW_DISMISS_SIZE)
  previewDismissButton:SetPoint("TOPRIGHT", previewFrame, "TOPRIGHT", 0, 0)
  if previewDismissButton.EnableMouse then
    previewDismissButton:EnableMouse(true)
  end
  local previewDismissBg = previewDismissButton:CreateTexture(nil, "BACKGROUND")
  previewDismissBg:SetAllPoints(previewDismissButton)
  applyVertexColor(previewDismissBg, { 0, 0, 0, 0 })
  local previewDismissLabel = previewDismissButton:CreateFontString(nil, "OVERLAY")
  setFontObject(previewDismissLabel, theme.FONTS.header_name or theme.FONTS.contact_name)
  previewDismissLabel:SetPoint("CENTER", previewDismissButton, "CENTER", 0, 0)
  previewDismissLabel:SetText("×")
  setTextColor(previewDismissLabel, DISMISS_COLOR)

  local senderLeft = PREVIEW_LEFT_PAD + PREVIEW_CLASS_ICON_SIZE + PREVIEW_ICON_GAP
  local previewSenderLabel = previewFrame:CreateFontString(nil, "OVERLAY")
  -- Font objects only: a raw SetFont on a FontString overrides the engine's
  -- Unicode glyph-fallback chain and blanks Cyrillic/Greek characters.
  setFontObject(previewSenderLabel, theme.FONTS.message_text)
  previewSenderLabel:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", senderLeft, PREVIEW_SENDER_TOP_OFFSET)
  previewSenderLabel:SetJustifyH("LEFT")
  previewSenderLabel:SetWordWrap(false)
  if previewSenderLabel.SetMaxLines then
    previewSenderLabel:SetMaxLines(1)
  end

  local previewMessageLabel = previewFrame:CreateFontString(nil, "OVERLAY")
  setFontObject(previewMessageLabel, theme.FONTS.system_text)
  previewMessageLabel:SetPoint("TOPLEFT", previewSenderLabel, "BOTTOMLEFT", 0, PREVIEW_MESSAGE_GAP)
  previewMessageLabel:SetJustifyH("LEFT")
  previewMessageLabel:SetWordWrap(false)
  if previewMessageLabel.SetMaxLines then
    previewMessageLabel:SetMaxLines(1)
  end
  previewFrame:Hide()

  local function stringWidthOf(fontString)
    if fontString and fontString.GetStringWidth then
      local ok, width = pcall(fontString.GetStringWidth, fontString)
      if ok and type(width) == "number" then
        return width
      end
    end
    return 0
  end

  local function resizePreviewToContent()
    local textLeft = PREVIEW_LEFT_PAD + PREVIEW_CLASS_ICON_SIZE + PREVIEW_ICON_GAP
    local maxMessageBudget = PREVIEW_MAX_WIDTH - textLeft - PREVIEW_RIGHT_PAD
    local maxSenderBudget = maxMessageBudget - PREVIEW_DISMISS_GAP - PREVIEW_DISMISS_SIZE

    if previewSenderLabel.SetWidth then
      previewSenderLabel:SetWidth(maxSenderBudget)
    end
    if previewMessageLabel.SetWidth then
      previewMessageLabel:SetWidth(maxMessageBudget)
    end

    local senderWidth = stringWidthOf(previewSenderLabel)
    local messageWidth = stringWidthOf(previewMessageLabel)
    if senderWidth > maxSenderBudget then
      senderWidth = maxSenderBudget
    end
    if messageWidth > maxMessageBudget then
      messageWidth = maxMessageBudget
    end

    local senderFootprint = senderWidth + PREVIEW_DISMISS_GAP + PREVIEW_DISMISS_SIZE
    local contentWidth = senderFootprint > messageWidth and senderFootprint or messageWidth
    local total = textLeft + contentWidth + PREVIEW_RIGHT_PAD
    if total < PREVIEW_MIN_WIDTH then
      total = PREVIEW_MIN_WIDTH
    elseif total > PREVIEW_MAX_WIDTH then
      total = PREVIEW_MAX_WIDTH
    end
    previewFrame:SetWidth(total)
  end

  local autoDismissGeneration = 0
  local lastPreviewSenderName = nil
  local lastPreviewMessageText = nil
  local lastPreviewClassTag = nil

  local function cancelAutoDismiss()
    autoDismissGeneration = autoDismissGeneration + 1
  end

  local function clearIncomingPreview()
    cancelAutoDismiss()
    lastPreviewSenderName = nil
    lastPreviewMessageText = nil
    lastPreviewClassTag = nil
    previewSenderLabel:SetText("")
    previewMessageLabel:SetText("")
    previewClassIcon:SetTexture(nil)
    previewClassIconFrame:Hide()
    previewFrame:Hide()
  end

  local function triggerDismiss()
    clearIncomingPreview()
    if options.onDismissPreview then
      options.onDismissPreview()
    end
  end

  local function scheduleAutoDismiss()
    cancelAutoDismiss()
    local getter = options.getPreviewAutoDismissSeconds
    local seconds = (type(getter) == "function") and tonumber(getter()) or 0
    if not seconds or seconds <= 0 then
      return
    end
    local cTimer = _G.C_Timer
    if type(cTimer) ~= "table" or type(cTimer.NewTimer) ~= "function" then
      return
    end
    local scheduledGeneration = autoDismissGeneration
    cTimer.NewTimer(seconds, function()
      if scheduledGeneration ~= autoDismissGeneration then
        return
      end
      if previewFrame.IsShown and not previewFrame:IsShown() then
        return
      end
      triggerDismiss()
    end)
  end

  if previewDismissButton.SetScript then
    previewDismissButton:SetScript("OnClick", triggerDismiss)
    previewDismissButton:SetScript("OnEnter", function()
      setTextColor(previewDismissLabel, DISMISS_COLOR_HOVER)
      applyVertexColor(previewDismissBg, DISMISS_BG_HOVER)
    end)
    previewDismissButton:SetScript("OnLeave", function()
      setTextColor(previewDismissLabel, DISMISS_COLOR)
      applyVertexColor(previewDismissBg, { 0, 0, 0, 0 })
    end)
  end

  if previewFrame.SetScript then
    previewFrame:SetScript("OnMouseUp", function(_self, button)
      if button == "RightButton" then
        triggerDismiss()
      end
    end)
  end

  local function setIncomingPreview(senderName, messageText, classTag)
    local hasMessage = type(messageText) == "string" and messageText ~= ""
    if not hasMessage then
      clearIncomingPreview()
      return
    end

    local isSameContent = senderName == lastPreviewSenderName
      and messageText == lastPreviewMessageText
      and classTag == lastPreviewClassTag

    previewSenderLabel:SetText(type(senderName) == "string" and senderName or "")
    previewMessageLabel:SetText(messageText)

    local classIconPath = theme.ClassIcon(classTag)
    if classIconPath then
      previewClassIcon:SetTexture(classIconPath)
    else
      previewClassIcon:SetTexture(theme.TEXTURES.bnet_icon)
    end
    previewClassIconFrame:Show()

    applyPreviewPosition(resolvePreviewPosition())
    previewFrame:Show()
    resizePreviewToContent()

    if not isSameContent then
      lastPreviewSenderName = senderName
      lastPreviewMessageText = messageText
      lastPreviewClassTag = classTag
      scheduleAutoDismiss()
    end
  end

  local function applyTheme(activeTheme)
    theme = activeTheme or theme
    if previewBackground and previewBackground.setColor then
      previewBackground.setColor(theme.COLORS.bg_secondary or theme.COLORS.bg_primary)
    end
    setTextColor(previewSenderLabel, theme.COLORS.text_primary)
    setTextColor(previewMessageLabel, theme.COLORS.text_secondary)
    setTextColor(previewDismissLabel, DISMISS_COLOR)
  end

  return {
    frame = previewFrame,
    senderLabel = previewSenderLabel,
    messageLabel = previewMessageLabel,
    dismissButton = previewDismissButton,
    dismissLabel = previewDismissLabel,
    classIcon = previewClassIcon,
    classIconFrame = previewClassIconFrame,
    setIncomingPreview = setIncomingPreview,
    applyPreviewPosition = applyPreviewPosition,
    applyTheme = applyTheme,
  }
end

ns.ToggleIconIncomingPreview = IncomingPreview

return IncomingPreview
