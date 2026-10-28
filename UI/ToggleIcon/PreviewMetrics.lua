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
}

local M = PreviewMetrics

local ANCHORS = {
  right = { selfPoint = "LEFT", target = "RIGHT", x = M.GAP, y = 0 },
  left = { selfPoint = "RIGHT", target = "LEFT", x = -M.GAP, y = 0 },
  top = { selfPoint = "BOTTOM", target = "TOP", x = 0, y = M.GAP },
  above = { selfPoint = "BOTTOM", target = "TOP", x = 0, y = M.GAP },
  bottom = { selfPoint = "TOP", target = "BOTTOM", x = 0, y = -M.GAP },
  below = { selfPoint = "TOP", target = "BOTTOM", x = 0, y = -M.GAP },
}

function PreviewMetrics.ResolveAnchor(position)
  return ANCHORS[position] or ANCHORS.right
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
-- (plus DETAIL_ROW_HEIGHT when the detail line shows).
local function fitHeight(previewFrame, senderLabel, messageLabel, detailLabel)
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
  previewFrame:SetHeight(needed > floor and needed or floor)
end

-- Gives the label its width budget; returns its text width, capped at that budget.
local function cappedWidthOf(label, budget)
  if label.SetWidth then
    label:SetWidth(budget)
  end
  local width = stringWidthOf(label)
  return width > budget and budget or width
end

-- detailLabel: pass it only while the detail line shows.
function PreviewMetrics.ResizeToContent(previewFrame, senderLabel, messageLabel, detailLabel)
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
  previewFrame:SetWidth(total)
  fitHeight(previewFrame, senderLabel, messageLabel, detailLabel)
end

ns.ToggleIconPreviewMetrics = PreviewMetrics
return PreviewMetrics
