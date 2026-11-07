local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local PreviewMetrics = ns.ToggleIconPreviewMetrics or require("WhisperMessenger.UI.ToggleIcon.PreviewMetrics")
local PreviewChrome = ns.ToggleIconPreviewChrome or require("WhisperMessenger.UI.ToggleIcon.PreviewChrome")
local PreviewDetailRow = ns.ToggleIconPreviewDetailRow or require("WhisperMessenger.UI.ToggleIcon.PreviewDetailRow")
local PreviewDismissButton = ns.ToggleIconPreviewDismissButton or require("WhisperMessenger.UI.ToggleIcon.PreviewDismissButton")
local setFontObject = UIHelpers.setFontObject

local PreviewCard = {}

-- Builds the preview card's widgets next to the icon frame, hidden.
function PreviewCard.Create(factory, frame, theme, getPreviewPosition)
  local previewFrame, previewBackground = PreviewChrome.Create(factory, frame)
  previewFrame:SetSize(PreviewMetrics.MAX_WIDTH, PreviewMetrics.HEIGHT)

  local positioner = PreviewMetrics.NewPositioner(previewFrame, frame, getPreviewPosition)
  positioner.apply(positioner.resolve())
  if previewFrame.SetFrameLevel then
    previewFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
  end
  -- The minimap icon reparents this frame to UIParent, which would otherwise drop it to MEDIUM strata.
  if previewFrame.SetFrameStrata then
    previewFrame:SetFrameStrata("HIGH")
  end
  -- A button riding the phone window changes strata; its preview stays up.
  if previewFrame.SetFixedFrameStrata then
    previewFrame:SetFixedFrameStrata(true)
  end
  if previewFrame.EnableMouse then
    previewFrame:EnableMouse(true)
  end

  local previewClassIconResult = UIHelpers.createCircularIcon(factory, previewFrame, PreviewMetrics.CLASS_ICON_SIZE)
  local previewClassIconFrame = previewClassIconResult.frame
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

  return {
    frame = previewFrame,
    background = previewBackground,
    positioner = positioner,
    classIconFrame = previewClassIconFrame,
    classIcon = previewClassIconResult.texture,
    dismiss = dismiss,
    senderLabel = previewSenderLabel,
    messageLabel = previewMessageLabel,
    detailRow = detailRow,
  }
end

ns.ToggleIconPreviewCard = PreviewCard

return PreviewCard
