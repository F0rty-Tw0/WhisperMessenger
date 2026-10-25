local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Size and anchor rules for the icon-anchored message preview.
local PreviewMetrics = {
  GAP = 8,
  MAX_WIDTH = 200,
  MIN_WIDTH = 60,
  HEIGHT = 42,
  CLASS_ICON_SIZE = 18,
  DISMISS_SIZE = 16,
  LEFT_PAD = 6,
  RIGHT_PAD = 6,
  ICON_GAP = 6,
  DISMISS_GAP = 4,
  SENDER_TOP_OFFSET = -8,
  MESSAGE_GAP = -1,
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

local function stringWidthOf(fontString)
  if fontString and fontString.GetStringWidth then
    local ok, width = pcall(fontString.GetStringWidth, fontString)
    if ok and type(width) == "number" then
      return width
    end
  end
  return 0
end

function PreviewMetrics.ResizeToContent(previewFrame, senderLabel, messageLabel)
  local textLeft = M.LEFT_PAD + M.CLASS_ICON_SIZE + M.ICON_GAP
  local maxMessageBudget = M.MAX_WIDTH - textLeft - M.RIGHT_PAD
  local maxSenderBudget = maxMessageBudget - M.DISMISS_GAP - M.DISMISS_SIZE

  if senderLabel.SetWidth then
    senderLabel:SetWidth(maxSenderBudget)
  end
  if messageLabel.SetWidth then
    messageLabel:SetWidth(maxMessageBudget)
  end

  local senderWidth = stringWidthOf(senderLabel)
  local messageWidth = stringWidthOf(messageLabel)
  if senderWidth > maxSenderBudget then
    senderWidth = maxSenderBudget
  end
  if messageWidth > maxMessageBudget then
    messageWidth = maxMessageBudget
  end

  local senderFootprint = senderWidth + M.DISMISS_GAP + M.DISMISS_SIZE
  local contentWidth = senderFootprint > messageWidth and senderFootprint or messageWidth
  local total = textLeft + contentWidth + M.RIGHT_PAD
  if total < M.MIN_WIDTH then
    total = M.MIN_WIDTH
  elseif total > M.MAX_WIDTH then
    total = M.MAX_WIDTH
  end
  previewFrame:SetWidth(total)
end

ns.ToggleIconPreviewMetrics = PreviewMetrics
return PreviewMetrics
