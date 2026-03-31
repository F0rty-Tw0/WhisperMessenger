local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local createCircularIcon = UIHelpers.createCircularIcon
local applyClassColor = UIHelpers.applyClassColor
local setTextColor = UIHelpers.setTextColor

local RowElements = {}

local NAME_ELLIPSIS = "..."
local NAME_LABEL_LEFT_INSET = 10
local NAME_TO_ICON_GAP = 4
local NAME_TO_TIME_GAP = 2
local TIME_LABEL_FALLBACK_WIDTH = 14
local TIME_LABEL_RIGHT_PADDING = 4
local FACTION_ICON_RIGHT_PADDING = 1
local UTF8_CHAR_PATTERN = "[%z\1-\127\194-\244][\128-\191]*"

local function timestampReserveWidth(row)
  local reserve = TIME_LABEL_RIGHT_PADDING + TIME_LABEL_FALLBACK_WIDTH + NAME_TO_TIME_GAP
  local timeLabel = row and row.timeLabel or nil
  if timeLabel == nil then
    return reserve
  end

  local liveWidth = 0
  if type(timeLabel.GetStringWidth) == "function" then
    liveWidth = timeLabel:GetStringWidth() or 0
  end
  if liveWidth <= 0 and type(timeLabel.GetWidth) == "function" then
    liveWidth = timeLabel:GetWidth() or 0
  end
  if type(liveWidth) == "number" and liveWidth > 0 then
    reserve = TIME_LABEL_RIGHT_PADDING + liveWidth + NAME_TO_TIME_GAP
  end

  return reserve
end

local function nameLabelWidth(row, parentWidth)
  return math.max(
    0,
    (parentWidth or 0)
      - Theme.LAYOUT.CONTACT_ICON_SIZE
      - Theme.LAYOUT.CONTACT_PADDING
      - NAME_LABEL_LEFT_INSET
      - timestampReserveWidth(row)
  )
end

local function utf8CodepointCount(text)
  local count = 0
  for _ in string.gmatch(text or "", UTF8_CHAR_PATTERN) do
    count = count + 1
  end
  return count
end

local function utf8Prefix(text, maxChars)
  if maxChars <= 0 then
    return ""
  end

  local chars = {}
  local index = 0
  for char in string.gmatch(text or "", UTF8_CHAR_PATTERN) do
    index = index + 1
    if index > maxChars then
      break
    end
    chars[#chars + 1] = char
  end

  return table.concat(chars)
end

local function fitLabelTextWithEllipsis(label, text, maxWidth)
  local resolvedText = text or ""
  label:SetText(resolvedText)
  if maxWidth <= 0 or type(label.GetStringWidth) ~= "function" then
    return resolvedText
  end

  if label:GetStringWidth() <= maxWidth then
    return resolvedText
  end

  label:SetText(NAME_ELLIPSIS)
  local ellipsisWidth = label:GetStringWidth() or 0
  if ellipsisWidth >= maxWidth then
    return NAME_ELLIPSIS
  end

  local totalChars = utf8CodepointCount(resolvedText)
  for keepChars = totalChars - 1, 1, -1 do
    local candidate = utf8Prefix(resolvedText, keepChars) .. NAME_ELLIPSIS
    label:SetText(candidate)
    if label:GetStringWidth() <= maxWidth then
      return candidate
    end
  end

  return NAME_ELLIPSIS
end

function RowElements.updateNameLabel(row, item, parentWidth)
  if row.title == nil then
    return
  end

  local width = nameLabelWidth(row, parentWidth)
  row.title:SetWidth(width)
  row.title:SetText(fitLabelTextWithEllipsis(row.title, item and item.displayName or "", width))
  applyClassColor(row.title, item and item.classTag or nil, Theme.COLORS.text_primary)
end


--- Create the circular class icon (40x40, left side).
--- Returns { frame, texture }
function RowElements.createClassIcon(factory, row, item)
  local icon = createCircularIcon(factory, row, Theme.LAYOUT.CONTACT_ICON_SIZE)
  row.classIconFrame = icon.frame
  row.classIcon = icon.texture
  row.classIconFrame:SetPoint("LEFT", row, "LEFT", Theme.LAYOUT.CONTACT_PADDING, 0)

  local iconPath = Theme.ClassIcon(item.classTag)
  if iconPath then
    row.classIcon:SetTexture(iconPath)
  else
    row.classIcon:SetTexture(Theme.TEXTURES.bnet_icon)
  end

  return icon
end

--- Create the contact name FontString (top line, class-colored).
--- Returns FontString
function RowElements.createNameLabel(row, item, parentWidth)
  local label = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_name)
  label:SetPoint("TOPLEFT", row.classIconFrame, "TOPRIGHT", NAME_LABEL_LEFT_INSET, -4)
  label:SetWidth(nameLabelWidth(row, parentWidth))
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  if label.SetMaxLines then
    label:SetMaxLines(1)
  end
  row.title = label
  RowElements.updateNameLabel(row, item, parentWidth)
  return label
end

function RowElements.updateFactionIcon(row, item, ns_ref)
  if row.factionIcon == nil then
    return
  end

  local inferredFaction = item.raceTag
      and (ns_ref and ns_ref.Identity and ns_ref.Identity.InferFaction and ns_ref.Identity.InferFaction(item.raceTag))
    or nil
  local factionForIcon = inferredFaction or item.factionName
  local reliableFaction = factionForIcon and Theme.FactionIcon(factionForIcon) or nil

  local titleMaxWidth = row.title and row.title.GetWidth and row.title:GetWidth() or 0
  local textBudget = titleMaxWidth
  if reliableFaction then
    textBudget = math.max(
      0,
      titleMaxWidth - Theme.LAYOUT.CONTACT_FACTION_SIZE - NAME_TO_ICON_GAP - FACTION_ICON_RIGHT_PADDING
    )
  end
  if row.title then
    row.title:SetText(fitLabelTextWithEllipsis(row.title, item.displayName or "", textBudget))
    applyClassColor(row.title, item.classTag, Theme.COLORS.text_primary)
  end

  local titleTextWidth = row.title and row.title.GetStringWidth and row.title:GetStringWidth() or 0
  local textW = math.min(titleTextWidth, textBudget)
  row.factionIcon:ClearAllPoints()
  if row.title then
    row.factionIcon:SetPoint("LEFT", row.title, "LEFT", textW + NAME_TO_ICON_GAP, 0)
  end

  if reliableFaction then
    row.factionIcon:SetTexture(reliableFaction)
    row.factionIcon:Show()
  else
    row.factionIcon:Hide()
  end
end

--- Create the faction icon texture (14x14, after name).
--- Returns texture (visible) or texture (hidden) depending on faction.
function RowElements.createFactionIcon(_factory, row, item, ns_ref)
  local tex = row:CreateTexture(nil, "ARTWORK")
  tex:SetSize(Theme.LAYOUT.CONTACT_FACTION_SIZE, Theme.LAYOUT.CONTACT_FACTION_SIZE)
  row.factionIcon = tex

  RowElements.updateFactionIcon(row, item, ns_ref)

  return tex
end

function RowElements.updateTimestamp(row, item, ns_ref)
  if row.timeLabel == nil then
    return
  end

  if ns_ref and ns_ref.TimeFormat and ns_ref.TimeFormat.ContactPreview then
    row.timeLabel:SetText(ns_ref.TimeFormat.ContactPreview(item.lastActivityAt))
  else
    row.timeLabel:SetText("")
  end
end

--- Create the timestamp FontString (top-right).
--- Returns FontString
function RowElements.createTimestamp(row, item, ns_ref)
  local label = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_time)
  label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -TIME_LABEL_RIGHT_PADDING, 0)
  if row.title then
    label:SetPoint("TOP", row.title, "TOP", 0, 4)
  end
  setTextColor(label, Theme.COLORS.text_secondary)
  row.timeLabel = label
  RowElements.updateTimestamp(row, item, ns_ref)

  return label
end

function RowElements.updatePreview(row, item, parentWidth, hideMessagePreview)
  if row.preview == nil then
    return
  end

  row.preview:SetWidth(parentWidth - Theme.LAYOUT.CONTACT_ICON_SIZE - Theme.LAYOUT.CONTACT_PADDING - 40)
  row.preview:SetText(hideMessagePreview and "" or (item.lastPreview or ""))
end

--- Create the preview text FontString (bottom line).
--- Returns FontString
function RowElements.createPreview(row, item, parentWidth)
  local label = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_preview)
  label:SetPoint("BOTTOMLEFT", row.classIconFrame, "BOTTOMRIGHT", 10, 2)
  setTextColor(label, Theme.COLORS.text_secondary)
  label:SetWidth(parentWidth - Theme.LAYOUT.CONTACT_ICON_SIZE - Theme.LAYOUT.CONTACT_PADDING - 40)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  if label.SetMaxLines then
    label:SetMaxLines(1)
  end
  row.preview = label
  RowElements.updatePreview(row, item, parentWidth, false)
  return label
end

ns.ContactsListRowElements = RowElements
return RowElements
