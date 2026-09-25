local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- Header additions for the player's own contact prefs: nickname (with the
-- real name dimmed beside it), a muted marker, and the note (gold "Note:"
-- label + text) on the right of the name row with the full text on hover.
local HeaderContactExtras = {}

local MUTED_ICON_SIZE = 14
local NOTE_RIGHT_INSET = 8
-- The note never takes more than this share of the header width.
local NOTE_MAX_WIDTH_PCT = 0.4
local NOTE_FALLBACK_WIDTH = 200
-- Clear space kept between the name row (name, faction icon, badge) and the note.
local NOTE_GAP = 12
-- Below this the note hides: "Note:" plus a couple of letters says nothing.
local NOTE_MIN_WIDTH = 60
-- Gap between the name, faction icon and badge (their LEFT/RIGHT anchors).
local NAME_ROW_GAP = 6

local function mutedIconEscape()
  local color = Theme.COLORS.text_secondary or { 1, 1, 1 }
  local function byte(value)
    return math.floor((tonumber(value) or 1) * 255 + 0.5)
  end
  return string.format(
    "|T%s:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t",
    Theme.TEXTURES.muted_icon,
    MUTED_ICON_SIZE,
    MUTED_ICON_SIZE,
    byte(color[1]),
    byte(color[2]),
    byte(color[3])
  )
end

-- baseTitle: what the header would show without prefs.
function HeaderContactExtras.Title(selectedContact, baseTitle, isGroup)
  local title = baseTitle or ""
  if not isGroup and selectedContact.nickname then
    title = selectedContact.nickname .. "  " .. UIHelpers.colorEscape(Theme.COLORS.text_secondary) .. title .. "|r"
  end
  if selectedContact.muted == true then
    title = title .. " " .. mutedIconEscape()
  end
  return title
end

local function showNoteTooltip(owner)
  local tooltip = _G.GameTooltip
  if tooltip == nil or type(tooltip.SetOwner) ~= "function" or owner._wmNote == nil then
    return
  end
  tooltip:SetOwner(owner, "ANCHOR_BOTTOM")
  -- Wrapped (5th argument) so a long note is not one very wide line. pcall
  -- as in the settings tooltips.
  pcall(tooltip.AddLine, tooltip, owner._wmNote, 1, 1, 1, true)
  tooltip:Show()
end

local function hideNoteTooltip()
  local tooltip = _G.GameTooltip
  if tooltip and type(tooltip.Hide) == "function" then
    tooltip:Hide()
  end
end

-- Adds view.headerNote (FontString) and view.headerNoteHitArea (hover frame).
function HeaderContactExtras.Create(factory, view, headerFrame, headerName)
  local note = headerFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_status)
  note:SetJustifyH("RIGHT")
  if type(note.SetWordWrap) == "function" then
    note:SetWordWrap(false)
  end
  if type(note.SetMaxLines) == "function" then
    note:SetMaxLines(1)
  end
  note:SetPoint("RIGHT", headerFrame, "RIGHT", -NOTE_RIGHT_INSET, 0)
  note:SetPoint("TOP", headerName, "TOP", 0, 0)
  note:Hide()

  local hitArea = factory.CreateFrame("Frame", nil, headerFrame)
  hitArea:SetAllPoints(note)
  if hitArea.EnableMouse then
    hitArea:EnableMouse(true)
  end
  hitArea:SetScript("OnEnter", showNoteTooltip)
  hitArea:SetScript("OnLeave", hideNoteTooltip)
  hitArea:Hide()

  view.headerNote = note
  view.headerNoteHitArea = hitArea
end

local function isShown(region)
  return region ~= nil and type(region.IsShown) == "function" and region:IsShown()
end

-- Where the name row's content ends: name, then faction icon and addon badge
-- when shown. Same left offset as the name's anchor in HeaderView.
local function nameRowRight(view)
  local right = Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER + Theme.LAYOUT.HEADER_ICON_SIZE + Theme.LAYOUT.HEADER_NAME_GAP
  if isShown(view.headerName) then
    right = right + view.headerName:GetStringWidth()
  end
  for _, region in ipairs({ view.headerFactionIcon, view.headerAddonBadgeButton }) do
    if isShown(region) then
      right = right + NAME_ROW_GAP + region:GetWidth()
    end
  end
  return right
end

local function hideNote(note, hitArea)
  note:SetText("")
  note:Hide()
  hitArea:Hide()
end

-- Re-fit the shown note to the current header width (after a resize).
function HeaderContactExtras.RefitNote(view)
  local note, hitArea = view.headerNote, view.headerNoteHitArea
  if note == nil then
    return
  end
  local text = hitArea._wmNote
  if text == nil then
    hideNote(note, hitArea)
    return
  end
  local headerWidth = type(view._headerWidth) == "number" and view._headerWidth > 0 and view._headerWidth or nil
  local maxWidth = NOTE_FALLBACK_WIDTH
  if headerWidth then
    local roomLeft = headerWidth - NOTE_RIGHT_INSET - NOTE_GAP - nameRowRight(view)
    maxWidth = math.min(math.floor(headerWidth * NOTE_MAX_WIDTH_PCT), math.floor(roomLeft))
  end
  -- ponytail: hide rather than wrap to another row; the note is still in the
  -- contact's right-click "Edit note…" dialog.
  if maxWidth < NOTE_MIN_WIDTH then
    hideNote(note, hitArea)
    return
  end
  note:SetWidth(maxWidth)
  -- Fit the plain note into what the label leaves, then colour both, so the
  -- ellipsis never cuts through a colour escape.
  local label = Localization.Text("Note:")
  note:SetText(label .. " ")
  local labelWidth = type(note.GetStringWidth) == "function" and note:GetStringWidth() or 0
  local fitted = UIHelpers.fitTextWithEllipsis(note, text, math.max(1, maxWidth - labelWidth))
  local gold, primary = UIHelpers.colorEscape(Theme.TAG_GOLD), UIHelpers.colorEscape(Theme.COLORS.text_primary)
  note:SetText(gold .. label .. "|r " .. primary .. fitted .. "|r")
  UIHelpers.applyColor(note, Theme.COLORS.text_primary)
  note:Show()
  hitArea:Show()
end

function HeaderContactExtras.Refresh(view, selectedContact, isGroup)
  if view.headerNoteHitArea == nil then
    return
  end
  view.headerNoteHitArea._wmNote = not isGroup and selectedContact and selectedContact.note or nil
  HeaderContactExtras.RefitNote(view)
end

ns.ConversationPaneHeaderContactExtras = HeaderContactExtras
return HeaderContactExtras
