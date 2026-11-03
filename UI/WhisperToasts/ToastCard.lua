local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local PreviewChrome = ns.ToggleIconPreviewChrome or require("WhisperMessenger.UI.ToggleIcon.PreviewChrome")

-- One pop-up card: class icon, sender name and the chat's newest line, on
-- the theme's plain rounded panel (never the game's HUD art). Styled like a
-- contact row so it follows the selected theme.
local ToastCard = {}

ToastCard.WIDTH = 260
ToastCard.HEIGHT = 48

local CORNER_RADIUS = 4
local ICON_SIZE = 24
local PAD = 10
local ICON_GAP = 8
local SENDER_TOP = -9
local LINE_GAP = -3
local FADE_SECONDS = 0.4

-- onClick(card) runs on a left click.
function ToastCard.Create(factory, parent, onClick)
  local frame = factory.CreateFrame("Button", nil, parent)
  frame:SetSize(ToastCard.WIDTH, ToastCard.HEIGHT)
  if frame.SetFrameStrata then
    frame:SetFrameStrata("HIGH")
  end
  if frame.EnableMouse then
    frame:EnableMouse(true)
  end
  local background = UIHelpers.createRoundedBackground(frame, CORNER_RADIUS)

  local icon = UIHelpers.createCircularIcon(factory, frame, ICON_SIZE)
  icon.frame:SetPoint("LEFT", frame, "LEFT", PAD, 0)

  local textLeft = PAD + ICON_SIZE + ICON_GAP
  local textWidth = ToastCard.WIDTH - textLeft - PAD
  local senderLabel = frame:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(senderLabel, Theme.FONTS.contact_name)
  senderLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, SENDER_TOP)
  senderLabel:SetWidth(textWidth)
  PreviewChrome.SingleLine(senderLabel)

  local messageLabel = frame:CreateFontString(nil, "OVERLAY")
  UIHelpers.setFontObject(messageLabel, Theme.FONTS.contact_preview)
  messageLabel:SetPoint("TOPLEFT", senderLabel, "BOTTOMLEFT", 0, LINE_GAP)
  messageLabel:SetWidth(textWidth)
  PreviewChrome.SingleLine(messageLabel)

  frame:Hide()
  local fade = HoverFade.Attach(frame, FADE_SECONDS)

  local card = { frame = frame, conversationKey = nil }

  frame:SetScript("OnClick", function()
    onClick(card)
  end)

  -- Reads the theme at render time, so a preset change shows on the next card.
  function card.render(entry)
    card.conversationKey = entry.conversationKey
    card.classTag = entry.classTag
    background.setColor(Theme.COLORS.bg_secondary or Theme.COLORS.bg_primary)
    senderLabel:SetText(entry.senderName or "")
    UIHelpers.applyClassColor(senderLabel, entry.classTag, Theme.COLORS.text_primary)
    messageLabel:SetText(ReactionAssets.FormatTextForDisplay(entry.messageText))
    UIHelpers.setTextColor(messageLabel, Theme.COLORS.text_secondary)
    icon.texture:SetTexture(Theme.ClassIcon(entry.classTag) or Theme.TEXTURES.bnet_icon)
  end

  function card.show()
    fade.set(true)
  end

  -- Fades out; the frame hides once the fade ends.
  function card.dismiss()
    card.conversationKey = nil
    fade.set(false)
  end

  return card
end

ns.WhisperToastsToastCard = ToastCard
return ToastCard
