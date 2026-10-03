local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local RemoveButton = ns.RemoveButton or require("WhisperMessenger.UI.Shared.RemoveButton")

-- One row of the ignore list: the name and blocked count on top, the reason
-- and the last blocked line below, and a remove button.
local IgnoreRow = {}

IgnoreRow.HEIGHT = 36

local TEXT_GAP = 8
local DETAIL_SEPARATOR = " - "

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

local function detailText(entry)
  local parts = {}
  if type(entry.reason) == "string" and entry.reason ~= "" then
    parts[#parts + 1] = entry.reason
  end
  if type(entry.lastText) == "string" and entry.lastText ~= "" then
    local label = IgnoreRow.ChannelLabel(entry.lastChannel)
    local line = label and ("[" .. label .. "] " .. entry.lastText) or entry.lastText
    parts[#parts + 1] = string.format(text("Last: %s"), line)
  end
  return table.concat(parts, DETAIL_SEPARATOR)
end

local function createText(row, font)
  local label = row:CreateFontString(nil, "OVERLAY", font)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  return label
end

function IgnoreRow.Create(factory, list, onRemove)
  local row = factory.CreateFrame("Frame", nil, list)
  row:SetHeight(IgnoreRow.HEIGHT)

  row.removeButton = RemoveButton.Create(factory, row, function()
    onRemove(row.entryKey)
  end)
  -- The name, the count and the button share the top line's centre.
  row.removeButton:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)

  row.blockedText = createText(row, Theme.FONTS.system_text)
  row.blockedText:SetPoint("RIGHT", row.removeButton, "LEFT", -TEXT_GAP, 0)
  row.blockedText:SetJustifyH("RIGHT")

  row.nameText = createText(row, Theme.FONTS.icon_label)
  row.nameText:SetPoint("LEFT", row, "TOPLEFT", 0, -RemoveButton.SIZE / 2)
  row.nameText:SetPoint("RIGHT", row.blockedText, "LEFT", -TEXT_GAP, 0)

  row.detailText = createText(row, Theme.FONTS.system_text)
  row.detailText:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
  row.detailText:SetPoint("RIGHT", row.removeButton, "LEFT", -TEXT_GAP, 0)

  IgnoreRow.RefreshTheme(row)
  return row
end

-- key: the entry's key in the ignore list, handed back to onRemove.
function IgnoreRow.Bind(row, entry, key)
  row.entryKey = key
  row.nameText:SetText(entry.name)
  row.blockedText:SetText(string.format(text("Blocked %d"), entry.blocked or 0))
  row.detailText:SetText(detailText(entry))
end

function IgnoreRow.RefreshTheme(row)
  UIHelpers.setTextColor(row.nameText, Theme.COLORS.text_primary)
  UIHelpers.setTextColor(row.blockedText, Theme.COLORS.text_secondary)
  UIHelpers.setTextColor(row.detailText, Theme.COLORS.text_secondary)
  RemoveButton.Paint(row.removeButton, false)
end

ns.FiltersSettingsIgnoreRow = IgnoreRow
return IgnoreRow
