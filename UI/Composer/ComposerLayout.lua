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

-- Horizontal padding between the input box edge and its text.
ComposerLayout.TEXT_INSET_X = 8

-- Extra viewport height above and below the text rows. A viewport exactly
-- one line pitch tall clips glyph descenders and hides the cursor, which is
-- taller than the pitch. Capped at the vertical inset so the viewport never
-- leaves the box.
ComposerLayout.TEXT_SLACK_Y = 3

-- `rows` text rows of `lineHeight` each: the box grows upward by one line per
-- extra row while the buttons keep their one-row position.
function ComposerLayout.Compute(width, rows, lineHeight)
  rows = rows or 1
  lineHeight = lineHeight or 0
  local layout = Theme.LAYOUT
  local gutter, size, gap = layout.COMPOSER_GUTTER, layout.COMPOSER_BUTTON_SIZE, layout.COMPOSER_BUTTON_GAP
  local oneRowH = layout.COMPOSER_HEIGHT - (gutter * 2)
  local inputH = oneRowH + (rows - 1) * lineHeight
  local textInsetY = math.max(0, math.floor((oneRowH - lineHeight) / 2))
  local textH = rows * lineHeight
  local slack = math.min(ComposerLayout.TEXT_SLACK_Y, textInsetY)

  return {
    inputX = gutter,
    inputY = gutter,
    inputW = width - (gutter * 2) - (size * 3) - (gap * 3),
    inputH = inputH,
    sendW = size,
    sendH = size,
    sendRight = gutter,
    textInsetY = textInsetY,
    textH = textH,
    textSlackY = slack,
    viewportY = textInsetY - slack,
    viewportH = textH + 2 * slack,
    sendBottom = gutter + (oneRowH - size) / 2,
    gap = gap,
    emojiSize = size,
    emojiIconSize = math.min(ReactionAssets.GetIconSize() * 2, size - EMOJI_PADDING),
  }
end

function ComposerLayout.TextWidth(width)
  return ComposerLayout.Compute(width).inputW - 2 * ComposerLayout.TEXT_INSET_X
end

-- Position every composer part for `width`; safe to call on every relayout.
function ComposerLayout.Apply(parts, width, rows, lineHeight)
  local m = ComposerLayout.Compute(width, rows, lineHeight)
  local pane = parts.pane
  local frame = parts.box
  frame:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", m.inputX, m.inputY)
  frame:SetSize(m.inputW, m.inputH)
  -- The scroll frame is the text viewport: the shown rows plus slack on both
  -- sides, so it clips there and the padding stays put. The edit box insets
  -- its text by the slack, so the text still starts textInsetY below the top.
  -- The insets are set only when the slack changes: setting them on the
  -- focused box, even to the same values, hides the game's cursor.
  local scroll = parts.scroll
  if scroll then
    local insetX, slack = ComposerLayout.TEXT_INSET_X, m.textSlackY
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -m.viewportY)
    scroll:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -m.viewportY)
    scroll:SetHeight(m.viewportH)
    parts.input:SetWidth(m.inputW)
    if parts.textSlackY ~= slack then
      parts.textSlackY = slack
      parts.input:SetTextInsets(insetX, insetX, slack, slack)
    end
  end
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
