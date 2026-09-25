local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Row state markers: the muted bell-slash left of the timestamp, and the
-- unread badge's muted (dim) and mention ("@") looks.
local RowMarkers = {}

local MARKER_SIZE = 12
local MARKER_GAP = 3

-- Horizontal space the muted marker takes from the name label.
RowMarkers.MUTED_RESERVE = MARKER_SIZE + MARKER_GAP

function RowMarkers.updateMuted(row, item)
  local muted = item ~= nil and item.muted == true
  if not muted then
    if row.mutedMarker then
      row.mutedMarker:Hide()
    end
    return
  end
  if row.mutedMarker == nil then
    local marker = row:CreateTexture(nil, "OVERLAY")
    marker:SetTexture(Theme.TEXTURES.muted_icon)
    row.mutedMarker = marker
  end
  local marker = row.mutedMarker
  marker:SetSize(MARKER_SIZE, MARKER_SIZE)
  marker:ClearAllPoints()
  marker:SetPoint("RIGHT", row.timeLabel or row, row.timeLabel and "LEFT" or "RIGHT", -MARKER_GAP, 0)
  UIHelpers.applyVertexColor(marker, Theme.COLORS.text_secondary)
  marker:Show()
end

-- Runs after RowElements.updateUnreadBadge, which sets the count ("@"
-- replaces it). Muted rows get the dim look; a mention always keeps the
-- accent look, even when muted. Set on every bind so pooled rows never keep
-- a stale look.
function RowMarkers.updateBadge(row, item)
  local badge = row.unreadBadge
  if badge == nil or item == nil then
    return
  end
  local mention = item.hasUnreadMention == true
  badge.setDim(item.muted == true and not mention)
  if mention and (tonumber(item.unreadCount) or 0) > 0 then
    badge.label:SetText("@")
  end
end

ns.ContactsListRowMarkers = RowMarkers
return RowMarkers
