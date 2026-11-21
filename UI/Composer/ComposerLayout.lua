local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")

-- Composer geometry: one gutter on every side, an input filling the strip
-- between them, and square quick-reply/emoji/send buttons vertically centered
-- on it with equal gaps. The emoji button is optional: with `buttonCount` 2
-- the input takes its space and quick reply sits next to send.
local ComposerLayout = {}

-- Quick reply, emoji and send; one fewer while the emoji button is hidden.
ComposerLayout.FULL_BUTTON_COUNT = 3

-- Room around the emoji glyph inside its square button.
local EMOJI_PADDING = 8

-- Horizontal padding between the input box edge and its text.
ComposerLayout.TEXT_INSET_X = 8

-- Extra viewport height below the text rows only. A viewport exactly one
-- line pitch tall clips glyph descenders and hides the cursor, which is
-- taller than the pitch. Slack above the rows would show a sliver of the line
-- scrolled out above them once a long message scrolls. Capped at the vertical
-- inset so the viewport never leaves the box.
ComposerLayout.TEXT_SLACK_Y = 3

-- `rows` text rows of `lineHeight` each: the box grows upward by one line per
-- extra row while the buttons keep their one-row position. `buttonCount` is 3
-- (quick reply, emoji, send) unless the emoji button is hidden (2).
function ComposerLayout.Compute(width, rows, lineHeight, buttonCount)
  rows = rows or 1
  buttonCount = buttonCount or ComposerLayout.FULL_BUTTON_COUNT
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
    inputW = width - (gutter * 2) - (size + gap) * buttonCount,
    inputH = inputH,
    sendW = size,
    sendH = size,
    sendRight = gutter,
    textInsetY = textInsetY,
    textH = textH,
    textSlackY = slack,
    viewportY = textInsetY,
    viewportH = textH + slack,
    sendBottom = gutter + (oneRowH - size) / 2,
    gap = gap,
    emojiSize = size,
    emojiIconSize = math.min(ReactionAssets.GetIconSize() * 2, size - EMOJI_PADDING),
  }
end

function ComposerLayout.TextWidth(width, buttonCount)
  return ComposerLayout.Compute(width, nil, nil, buttonCount).inputW - 2 * ComposerLayout.TEXT_INSET_X
end

-- Position every composer part for `width`; safe to call on every relayout.
function ComposerLayout.Apply(parts, width, rows, lineHeight, buttonCount)
  local m = ComposerLayout.Compute(width, rows, lineHeight, buttonCount)
  local pane = parts.pane
  local frame = parts.box
  frame:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", m.inputX, m.inputY)
  frame:SetSize(m.inputW, m.inputH)
  -- The scroll frame is the text viewport: it starts textInsetY below the box
  -- top and holds the shown rows plus slack below them, so it clips there and
  -- the padding stays put. The edit box insets its text bottom by the slack.
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
      parts.input:SetTextInsets(insetX, insetX, 0, slack)
    end
  end
  parts.sendButton:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -m.sendRight, m.sendBottom)
  parts.sendButton:SetSize(m.sendW, m.sendH)
  -- The emoji button keeps its spot while hidden, so showing it needs no extra step.
  parts.emojiButton:SetPoint("RIGHT", parts.sendButton, "LEFT", -m.gap, 0)
  parts.emojiButton:SetSize(m.emojiSize, m.emojiSize)
  parts.emojiIcon:SetSize(m.emojiIconSize, m.emojiIconSize)
  local emojiHidden = buttonCount == ComposerLayout.FULL_BUTTON_COUNT - 1
  local quickReplyAnchor = emojiHidden and parts.sendButton or parts.emojiButton
  parts.quickReplyButton:SetPoint("RIGHT", quickReplyAnchor, "LEFT", -m.gap, 0)
  parts.quickReplyButton:SetSize(m.emojiSize, m.emojiSize)
  parts.quickReplyButton.icon:SetSize(m.emojiIconSize, m.emojiIconSize)
end

ns.ComposerLayout = ComposerLayout
return ComposerLayout
