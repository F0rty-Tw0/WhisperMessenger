local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local StatusLine = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine")
local GroupLabel = ns.ContactsListGroupLabel or require("WhisperMessenger.UI.ContactsList.GroupLabel")
local RailAvatar = ns.ContactsListRailAvatar or require("WhisperMessenger.UI.ContactsList.RailAvatar")

-- Hover card for collapsed-rail rows, which show no text of their own: who
-- it is, where, their status, the last line and the unread count.
local RowTooltip = {}

-- GameTooltip is dark in every theme, so its text keeps the game's colours.
local TITLE_COLOR = { 1, 1, 1 }
local DETAIL_COLOR = { 0.8, 0.8, 0.8 }
local MESSAGE_COLOR = { 1, 1, 1 }

local function add(lines, text, color)
  if type(text) == "string" and text ~= "" then
    lines[#lines + 1] = { text = text, color = color }
  end
end

-- "Name" plus the realm for characters; the (formatted) BattleTag for
-- Battle.net friends when it says more than the name does.
local function nameAndDetail(item)
  if item.channel == "BN" then
    local name = DisplayName.Format(item.displayName) or ""
    local tag = item.battleTag and DisplayName.Format(item.battleTag) or nil
    return name, tag ~= name and tag or nil
  end
  local fullName = item.displayName or ""
  return string.match(fullName, "^([^%-]+)") or fullName, string.match(fullName, "%-(.+)$")
end

local function statusLine(item)
  if item.isTyping then
    return Localization.Text("typing…"), Theme.COLORS.online
  end
  local avail = item.availability and StatusLine.AVAILABILITY_DISPLAY[item.availability.status]
  if avail == nil then
    return nil
  end
  return Localization.Text(avail.label), Theme.COLORS[avail.color]
end

local function personLines(lines, item)
  local name, detail = nameAndDetail(item)
  local r, g, b = RailAvatar.ClassColor(item.classTag)
  add(lines, item.nickname and (item.nickname .. " (" .. name .. ")") or name, r and { r, g, b } or TITLE_COLOR)
  add(lines, detail, DETAIL_COLOR)
  add(lines, item.areaName, DETAIL_COLOR)
  local status, statusColor = statusLine(item)
  add(lines, status, statusColor or DETAIL_COLOR)
end

-- Lines as { text, color }, title first. hideMessagePreview leaves out the
-- last message (the player's privacy setting).
function RowTooltip.Lines(item, hideMessagePreview)
  local lines = {}
  local isGroup = GroupLabel.IsGroupItem(item)
  if isGroup then
    add(lines, GroupLabel.ForItem(item), TITLE_COLOR)
  else
    personLines(lines, item)
  end
  if not hideMessagePreview then
    add(lines, ReactionAssets.FormatTextForDisplay(item.lastPreview), MESSAGE_COLOR)
  end
  local unread = tonumber(item.unreadCount) or 0
  if not isGroup and unread > 0 then
    add(lines, unread .. " " .. Localization.Text("unread"), Theme.COLORS.accent or DETAIL_COLOR)
  end
  return lines
end

function RowTooltip.Show(row)
  local tooltip = _G.GameTooltip
  if row.item == nil or tooltip == nil or type(tooltip.SetOwner) ~= "function" then
    return
  end
  local options = row._wmRowOptions
  local lines = RowTooltip.Lines(row.item, options and options.hideMessagePreview)
  if lines[1] == nil then
    return
  end
  tooltip:SetOwner(row, "ANCHOR_RIGHT")
  local title = lines[1]
  tooltip:SetText(title.text, title.color[1], title.color[2], title.color[3])
  for index = 2, #lines do
    local line = lines[index]
    -- Wrapped (5th argument) so a long last message is not one wide line.
    -- pcall as in the contact note tooltip.
    pcall(tooltip.AddLine, tooltip, line.text, line.color[1], line.color[2], line.color[3], true)
  end
  tooltip:Show()
  row._wmTooltipShown = true
end

-- Only hides the tooltip this row opened (an action button's tooltip on a
-- full-list row is left alone).
function RowTooltip.Hide(row)
  if not row._wmTooltipShown then
    return
  end
  row._wmTooltipShown = false
  local tooltip = _G.GameTooltip
  if tooltip and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

ns.ContactsListRowTooltip = RowTooltip
return RowTooltip
