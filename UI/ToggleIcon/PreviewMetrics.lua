local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Size and anchor rules for the icon-anchored message preview.
local PreviewMetrics = {
  GAP = 8,
  MAX_WIDTH = 240,
  MIN_WIDTH = 60,
  HEIGHT = 56,
  CLASS_ICON_SIZE = 22,
  DISMISS_SIZE = 16,
  LEFT_PAD = 10,
  RIGHT_PAD = 10,
  ICON_GAP = 8,
  DISMISS_GAP = 4,
  -- Close button's offset from the top-right corner: just inside the ~5px HUD tooltip border.
  DISMISS_INSET = 6,
  SENDER_TOP_OFFSET = -11,
  MESSAGE_GAP = -3,
  -- Optional third line (an addon preview's detail) under the message line.
  DETAIL_GAP = -3,
  -- What the detail line adds to HEIGHT: its gap plus one 12px message-font line.
  DETAIL_ROW_HEIGHT = 15,
  -- Clear space under the message line; keeps the link off the ~5px HUD tooltip border.
  BOTTOM_ROOM = 14,
  -- The optional reply row under the card's text: its height, the room it
  -- adds above itself, and the card width it needs to be usable.
  REPLY_ROW_HEIGHT = 22,
  REPLY_ROW_GAP = 6,
  REPLY_MIN_WIDTH = 220,
}

local M = PreviewMetrics

local ANCHORS = {
  right = { selfPoint = "LEFT", target = "RIGHT", x = M.GAP, y = 0 },
  left = { selfPoint = "RIGHT", target = "LEFT", x = -M.GAP, y = 0 },
  top = { selfPoint = "BOTTOM", target = "TOP", x = 0, y = M.GAP },
  above = { selfPoint = "BOTTOM", target = "TOP", x = 0, y = M.GAP },
  bottom = { selfPoint = "TOP", target = "BOTTOM", x = 0, y = -M.GAP },
  below = { selfPoint = "TOP", target = "BOTTOM", x = 0, y = -M.GAP },
  detached = { selfPoint = "TOP", target = "TOP", x = 0, y = 0 },
}

function PreviewMetrics.ResolveAnchor(position)
  return ANCHORS[position] or ANCHORS.right
end

-- Places the card next to its icon. resolve() prefers the getter's answer,
-- else the last applied position.
function PreviewMetrics.NewPositioner(previewFrame, anchorFrame, getPreviewPosition)
  local currentPosition = "right"

  local function apply(position)
    local nextPosition = (type(position) == "string" and position ~= "") and position or "right"
    currentPosition = nextPosition
    local anchor = PreviewMetrics.ResolveAnchor(nextPosition)
    if previewFrame.ClearAllPoints then
      previewFrame:ClearAllPoints()
    end
    if previewFrame.SetPoint then
      previewFrame:SetPoint(anchor.selfPoint, anchorFrame, anchor.target, anchor.x, anchor.y)
    end
  end

  local function resolve()
    if type(getPreviewPosition) == "function" then
      local ok, value = pcall(getPreviewPosition)
      if ok and type(value) == "string" and value ~= "" then
        return value
      end
    end
    return currentPosition
  end

  return { apply = apply, resolve = resolve }
end

local function measureOf(fontString, methodName)
  local method = fontString and fontString[methodName]
  if method then
    local ok, value = pcall(method, fontString)
    if ok and type(value) == "number" then
      return value
    end
  end
  return 0
end

local function stringWidthOf(fontString)
  return measureOf(fontString, "GetStringWidth")
end

-- Tall enough for every line at the player's Font Size, never below HEIGHT
-- (plus DETAIL_ROW_HEIGHT when the detail line shows), then the reply row under it.
local function fitHeight(previewFrame, senderLabel, messageLabel, detailLabel, replyHeight)
  if not previewFrame.SetHeight then
    return
  end
  local needed = -M.SENDER_TOP_OFFSET
    + measureOf(senderLabel, "GetStringHeight")
    - M.MESSAGE_GAP
    + measureOf(messageLabel, "GetStringHeight")
    + M.BOTTOM_ROOM
  local floor = M.HEIGHT
  if detailLabel then
    needed = needed - M.DETAIL_GAP + measureOf(detailLabel, "GetStringHeight")
    floor = floor + M.DETAIL_ROW_HEIGHT
  end
  previewFrame:SetHeight((needed > floor and needed or floor) + replyHeight)
end

-- Gives the label its width budget; returns its text width, capped at that budget.
local function cappedWidthOf(label, budget)
  if label.SetWidth then
    label:SetWidth(budget)
  end
  local width = stringWidthOf(label)
  return width > budget and budget or width
end

-- detailLabel: pass it only while the detail line shows. replyHeight: the
-- reply row's height while it shows; nil or 0 keeps the plain card.
function PreviewMetrics.ResizeToContent(previewFrame, senderLabel, messageLabel, detailLabel, replyHeight)
  replyHeight = replyHeight or 0
  local textLeft = M.LEFT_PAD + M.CLASS_ICON_SIZE + M.ICON_GAP
  local maxMessageBudget = M.MAX_WIDTH - textLeft - M.RIGHT_PAD
  local maxSenderBudget = maxMessageBudget - M.DISMISS_GAP - M.DISMISS_SIZE

  local senderWidth = cappedWidthOf(senderLabel, maxSenderBudget)
  local messageWidth = cappedWidthOf(messageLabel, maxMessageBudget)
  local senderFootprint = senderWidth + M.DISMISS_GAP + M.DISMISS_SIZE
  local contentWidth = senderFootprint > messageWidth and senderFootprint or messageWidth
  local detailWidth = detailLabel and cappedWidthOf(detailLabel, maxMessageBudget) or 0
  if detailWidth > contentWidth then
    contentWidth = detailWidth
  end
  local total = textLeft + contentWidth + M.RIGHT_PAD
  if total < M.MIN_WIDTH then
    total = M.MIN_WIDTH
  elseif total > M.MAX_WIDTH then
    total = M.MAX_WIDTH
  end
  if replyHeight > 0 and total < M.REPLY_MIN_WIDTH then
    total = M.REPLY_MIN_WIDTH
  end
  previewFrame:SetWidth(total)
  fitHeight(previewFrame, senderLabel, messageLabel, detailLabel, replyHeight)
end

-- Centers the class icon on the text, above the reply row while it shows.
-- Returns its anchor (false = plain, else y offset); pass it back as lastAnchor.
function PreviewMetrics.AnchorClassIcon(iconFrame, previewFrame, replyHeight, lastAnchor)
  ---@type number|false
  local anchor = false
  if replyHeight and replyHeight > 0 then
    anchor = -(previewFrame:GetHeight() - replyHeight) / 2
  end
  if anchor == lastAnchor then
    return anchor
  end
  iconFrame:ClearAllPoints()
  if anchor == false then
    iconFrame:SetPoint("LEFT", previewFrame, "LEFT", M.LEFT_PAD, 0)
  else
    iconFrame:SetPoint("LEFT", previewFrame, "TOPLEFT", M.LEFT_PAD, anchor)
  end
  return anchor
end

ns.ToggleIconPreviewMetrics = PreviewMetrics
return PreviewMetrics
