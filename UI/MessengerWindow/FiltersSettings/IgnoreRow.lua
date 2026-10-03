local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local RemoveButton = ns.RemoveButton or require("WhisperMessenger.UI.Shared.RemoveButton")
local BlockedCount = ns.FiltersSettingsBlockedCount or require("WhisperMessenger.UI.MessengerWindow.FiltersSettings.BlockedCount")

-- One row of the block list: the name on top, then this session's blocked
-- count, the reason and the last blocked line below, and a remove button.
-- Both lines stay one line and truncate; hovering the row shows them in full.
local IgnoreRow = {}

local TEXT_GAP = 8
-- Half the space between the name line and the line below, at the row's centre.
local LINE_GAP = 1
local DETAIL_SEPARATOR = " - "
-- GameTooltip is dark in every theme, so its text keeps the game's colours.
local TOOLTIP_TITLE_COLOR = { 1, 1, 1 }
local TOOLTIP_DETAIL_COLOR = { 0.8, 0.8, 0.8 }

-- Whisper and group lines record the chat event; show the player's word for
-- it. Channel lines record the channel name, which is shown as is.
local EVENT_LABELS = {
  CHAT_MSG_WHISPER = "Whisper",
  CHAT_MSG_BN_WHISPER = "Whisper",
  CHAT_MSG_PARTY = "Party",
  CHAT_MSG_PARTY_LEADER = "Party",
  CHAT_MSG_RAID = "Raid",
  CHAT_MSG_RAID_LEADER = "Raid",
  CHAT_MSG_RAID_WARNING = "Raid",
  CHAT_MSG_INSTANCE_CHAT = "Instance (BG)",
  CHAT_MSG_INSTANCE_CHAT_LEADER = "Instance (BG)",
  CHAT_MSG_GUILD = "Guild",
  CHAT_MSG_OFFICER = "Officer",
  CHAT_MSG_BN_CONVERSATION = "Battle.net Group",
  CHAT_MSG_COMMUNITIES_CHANNEL = "Community",
}

local function text(key)
  return Localization.Text(key)
end

function IgnoreRow.ChannelLabel(lastChannel)
  if type(lastChannel) ~= "string" or lastChannel == "" then
    return nil
  end
  local key = EVENT_LABELS[lastChannel]
  if key ~= nil then
    return text(key)
  end
  if string.find(lastChannel, "^CHAT_MSG_") then
    return nil
  end
  return lastChannel
end

-- The count, then the reason and the last blocked line when there are any.
local function detailParts(entry)
  local parts = { BlockedCount.Text(entry.blocked) }
  if type(entry.reason) == "string" and entry.reason ~= "" then
    parts[#parts + 1] = entry.reason
  end
  if type(entry.lastText) == "string" and entry.lastText ~= "" then
    local label = IgnoreRow.ChannelLabel(entry.lastChannel)
    local line = label and ("[" .. label .. "] " .. entry.lastText) or entry.lastText
    parts[#parts + 1] = string.format(text("Last: %s"), line)
  end
  return parts
end

local function showTooltip(row)
  local tooltip = _G.GameTooltip
  if row.entry == nil or tooltip == nil or type(tooltip.SetOwner) ~= "function" then
    return
  end
  tooltip:SetOwner(row, "ANCHOR_TOP")
  tooltip:SetText(row.entry.name, TOOLTIP_TITLE_COLOR[1], TOOLTIP_TITLE_COLOR[2], TOOLTIP_TITLE_COLOR[3])
  for _, part in ipairs(detailParts(row.entry)) do
    -- Wrapped (5th argument) so a long message is not one very wide line.
    pcall(tooltip.AddLine, tooltip, part, TOOLTIP_DETAIL_COLOR[1], TOOLTIP_DETAIL_COLOR[2], TOOLTIP_DETAIL_COLOR[3], true)
  end
  tooltip:Show()
  row.tooltipShown = true
end

-- Only hides the tooltip this row opened, not the remove button's.
local function hideTooltip(row)
  if not row.tooltipShown then
    return
  end
  row.tooltipShown = false
  local tooltip = _G.GameTooltip
  if tooltip and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

local function createText(row, font)
  local label = row:CreateFontString(nil, "OVERLAY", font)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  if label.SetMaxLines then
    label:SetMaxLines(1)
  end
  return label
end

function IgnoreRow.Create(factory, list, onRemove)
  local row = factory.CreateFrame("Frame", nil, list)

  row.removeButton = RemoveButton.Create(factory, row, function()
    onRemove(row.entryKey)
  end, "Unblock")
  row.removeButton:SetPoint("RIGHT", row, "RIGHT", 0, 0)

  row:EnableMouse(true)
  row:SetScript("OnEnter", showTooltip)
  row:SetScript("OnLeave", hideTooltip)

  -- The two lines meet at the row's centre, level with the button.
  row.nameText = createText(row, Theme.FONTS.icon_label)
  row.nameText:SetPoint("BOTTOMLEFT", row, "LEFT", 0, LINE_GAP)
  row.nameText:SetPoint("BOTTOMRIGHT", row.removeButton, "LEFT", -TEXT_GAP, LINE_GAP)

  row.detailText = createText(row, Theme.FONTS.system_text)
  row.detailText:SetPoint("TOPLEFT", row, "LEFT", 0, -LINE_GAP)
  row.detailText:SetPoint("TOPRIGHT", row.removeButton, "LEFT", -TEXT_GAP, -LINE_GAP)

  IgnoreRow.RefreshTheme(row)
  return row
end

-- key: the entry's key in the ignore list, handed back to onRemove.
function IgnoreRow.Bind(row, entry, key)
  row.entryKey = key
  row.entry = entry
  row.nameText:SetText(entry.name)
  row.detailText:SetText(table.concat(detailParts(entry), DETAIL_SEPARATOR))
end

function IgnoreRow.RefreshTheme(row)
  UIHelpers.setTextColor(row.nameText, Theme.COLORS.text_primary)
  UIHelpers.setTextColor(row.detailText, Theme.COLORS.text_secondary)
  RemoveButton.Paint(row.removeButton, false)
end

ns.FiltersSettingsIgnoreRow = IgnoreRow
return IgnoreRow
