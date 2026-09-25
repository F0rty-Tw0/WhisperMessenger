local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")

-- Composer geometry: one gutter on every side, an input filling the strip
-- between them, and square quick-reply/emoji/send buttons vertically centered
-- on it with equal gaps.
local ComposerLayout = {}

-- Room around the emoji glyph inside its square button.
local EMOJI_PADDING = 8

function ComposerLayout.Compute(width)
  local layout = Theme.LAYOUT
  local gutter, size, gap = layout.COMPOSER_GUTTER, layout.COMPOSER_BUTTON_SIZE, layout.COMPOSER_BUTTON_GAP
  local inputH = layout.COMPOSER_HEIGHT - (gutter * 2)
  return {
    inputX = gutter,
    inputY = gutter,
    inputW = width - (gutter * 2) - (size * 3) - (gap * 3),
    inputH = inputH,
    sendW = size,
    sendH = size,
    sendRight = gutter,
    sendBottom = gutter + (inputH - size) / 2,
    gap = gap,
    emojiSize = size,
    emojiIconSize = math.min(ReactionAssets.GetIconSize() * 2, size - EMOJI_PADDING),
  }
end

-- Position every composer part for `width`; safe to call on every relayout.
function ComposerLayout.Apply(parts, width)
  local m = ComposerLayout.Compute(width)
  local pane = parts.pane
  parts.input:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", m.inputX, m.inputY)
  parts.input:SetSize(m.inputW, m.inputH)
  parts.sendButton:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -m.sendRight, m.sendBottom)
  parts.sendButton:SetSize(m.sendW, m.sendH)
  parts.emojiButton:SetPoint("RIGHT", parts.sendButton, "LEFT", -m.gap, 0)
  parts.emojiButton:SetSize(m.emojiSize, m.emojiSize)
  parts.emojiIcon:SetSize(m.emojiIconSize, m.emojiIconSize)
  parts.quickReplyButton:SetPoint("RIGHT", parts.emojiButton, "LEFT", -m.gap, 0)
  parts.quickReplyButton:SetSize(m.emojiSize, m.emojiSize)
  parts.quickReplyButton.icon:SetSize(m.emojiIconSize, m.emojiIconSize)
end

ns.ComposerLayout = ComposerLayout
return ComposerLayout
