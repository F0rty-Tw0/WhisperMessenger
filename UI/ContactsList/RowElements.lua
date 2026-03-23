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
  label:SetPoint("TOPLEFT", row.classIconFrame, "TOPRIGHT", 10, -4)
  label:SetWidth(parentWidth - Theme.LAYOUT.CONTACT_ICON_SIZE - Theme.LAYOUT.CONTACT_PADDING - 60)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  if label.SetMaxLines then
    label:SetMaxLines(1)
  end
  row.title = label
  label:SetText(item.displayName)
  applyClassColor(label, item.classTag, Theme.COLORS.text_primary)
  return label
end

--- Create the faction icon texture (14x14, after name).
--- Returns texture (visible) or texture (hidden) depending on faction.
function RowElements.createFactionIcon(factory, row, item, ns_ref)
  local tex = row:CreateTexture(nil, "ARTWORK")
  tex:SetSize(Theme.LAYOUT.CONTACT_FACTION_SIZE, Theme.LAYOUT.CONTACT_FACTION_SIZE)
  row.factionIcon = tex

  local titleTextWidth = row.title and row.title.GetStringWidth and row.title:GetStringWidth() or 0
  local titleMaxWidth = row.title and row.title.GetWidth and row.title:GetWidth() or 0
  local textW = math.min(titleTextWidth, titleMaxWidth)
  tex:ClearAllPoints()
  if row.title then
    tex:SetPoint("LEFT", row.title, "LEFT", textW + 4, 0)
  end

  local inferredFaction = item.raceTag
      and (ns_ref and ns_ref.Identity and ns_ref.Identity.InferFaction and ns_ref.Identity.InferFaction(item.raceTag))
    or nil
  local factionForIcon = inferredFaction or item.factionName
  local reliableFaction = factionForIcon and Theme.FactionIcon(factionForIcon) or nil
  if reliableFaction then
    tex:SetTexture(reliableFaction)
    tex:Show()
  else
    tex:Hide()
  end

  return tex
end

--- Create the timestamp FontString (top-right).
--- Returns FontString
function RowElements.createTimestamp(row, item, ns_ref)
  local label = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_time)
  label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -Theme.LAYOUT.CONTACT_PADDING, 0)
  if row.title then
    label:SetPoint("TOP", row.title, "TOP", 0, 4)
  end
  setTextColor(label, Theme.COLORS.text_secondary)
  row.timeLabel = label

  if ns_ref and ns_ref.TimeFormat and ns_ref.TimeFormat.ContactPreview then
    label:SetText(ns_ref.TimeFormat.ContactPreview(item.lastActivityAt))
  else
    label:SetText("")
  end

  return label
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
  label:SetText(item.lastPreview or "")
  return label
end

ns.ContactsListRowElements = RowElements
return RowElements
