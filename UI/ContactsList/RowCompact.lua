local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local RailAvatar = ns.ContactsListRailAvatar or require("WhisperMessenger.UI.ContactsList.RailAvatar")
local unpackValues = table.unpack or _G.unpack

-- Compact ("rail") look of a bound contact row: only the icon is left,
-- centred, with the unread badge on its top-right corner and the status dot
-- on its bottom-right. People get an initials avatar, group chats keep their
-- achievement art; both stay in the class icons' squircle. Runs at the end
-- of every bind; the full row is restored when a row that was compact binds
-- expanded again.
local RowCompact = {}

-- How far the badge pokes past the icon's corner.
local BADGE_CORNER_OFFSET = 4

-- Moves the icon from the row's centre to the rail's. Rows start
-- CONTACT_ROW_LEFT_INSET in, and under the Native WoW HUD the list stops
-- HUD_PANEL_PADDING short of the pane's right edge, so the row centre is off
-- the pane centre (where the magnifier sits) by half the difference.
local function railIconOffsetX()
  local layout = Theme.LAYOUT
  local rightInset = Hud.IsOn() and layout.HUD_PANEL_PADDING or 0
  return (rightInset - layout.CONTACT_ROW_LEFT_INSET) / 2
end

local function setShown(region, shown)
  if region and region.SetShown then
    region:SetShown(shown)
  end
end

-- The full-row anchor is read once, before the first compact re-anchor, and
-- put back on expand.
local function reanchor(region, savedKey, row, compact, ...)
  if region == nil then
    return
  end
  if row[savedKey] == nil then
    row[savedKey] = { region:GetPoint() }
  end
  region:ClearAllPoints()
  if compact then
    region:SetPoint(...)
  else
    region:SetPoint(unpackValues(row[savedKey]))
  end
end

local function applyCompact(row, item, isGroup)
  setShown(row.title, false)
  setShown(row.preview, false)
  setShown(row.timeLabel, false)
  setShown(row.location, false)
  setShown(row.factionIcon, false)
  setShown(row.mutedMarker, false)
  setShown(row.pinButton, false)
  setShown(row.removeButton, false)
  setShown(row.pinnedMarker, false)

  -- Group art was already set on the class icon by the bind.
  if isGroup then
    RailAvatar.hide(row)
  else
    RailAvatar.update(row, item)
  end
end

-- Location, faction, muted and action visibility were already set by the
-- normal bind; only what compact mode alone hides comes back here.
local function restoreFull(row)
  setShown(row.title, true)
  setShown(row.preview, true)
  setShown(row.timeLabel, true)
  RailAvatar.hide(row)
end

function RowCompact.apply(row, item, isGroup, compact)
  if not compact and not row._wmCompactApplied then
    return
  end
  row._wmCompactApplied = compact
  reanchor(row.classIconFrame, "_wmFullIconPoint", row, compact, "CENTER", row, "CENTER", railIconOffsetX(), 0)
  local badgeFrame = row.unreadBadge and row.unreadBadge.frame
  reanchor(badgeFrame, "_wmFullBadgePoint", row, compact, "TOPRIGHT", row.classIconFrame, "TOPRIGHT", BADGE_CORNER_OFFSET, BADGE_CORNER_OFFSET)
  if compact then
    applyCompact(row, item, isGroup)
  else
    restoreFull(row)
  end
end

ns.ContactsListRowCompact = RowCompact
return RowCompact
