local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local applyColorTexture = UIHelpers.applyColorTexture
local applyVertexColor = UIHelpers.applyVertexColor

local TabToggle = {}

local TAB_HEIGHT = 24
local BADGE_SIZE = 14
local BADGE_GAP = 4
local BADGE_CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function createBadge(factory, parentButton, anchorLabel)
  local badge = factory.CreateFrame("Frame", nil, parentButton)
  badge:SetSize(BADGE_SIZE, BADGE_SIZE)
  badge:SetPoint("LEFT", anchorLabel, "RIGHT", BADGE_GAP, 0)

  local bg = badge:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(badge)
  bg:SetTexture(BADGE_CIRCLE_TEX)
  applyVertexColor(bg, Theme.COLORS.unread_badge or Theme.COLORS.badge_bg)

  local label = badge:CreateFontString(nil, "OVERLAY", Theme.FONTS.unread_badge)
  label:SetAllPoints(badge)
  label:SetJustifyH("CENTER")
  label:SetJustifyV("MIDDLE")
  label:SetText("")

  if badge.Hide then
    badge:Hide()
  end

  return { frame = badge, bg = bg, label = label }
end

-- Create builds a two-segment Whispers/Groups toggle control anchored to
-- the bottom of the parent contacts pane.
--
-- options:
--   parent        : parent frame
--   initialMode   : "whispers" | "groups"  (default "whispers")
--   onModeChanged : function(mode)
--
-- Returns:
--   { frame, setMode, getMode, setShown }
function TabToggle.Create(factory, parent, options)
  options = options or {}
  local onModeChanged = options.onModeChanged or function(_mode) end
  local currentMode = options.initialMode or "whispers"

  local ACTIVE_BG = Theme.COLORS.bg_contact_selected or Theme.COLORS.accent_bar
  local INACTIVE_BG = Theme.COLORS.bg_primary or Theme.COLORS.bg_secondary
  local ACTIVE_TEXT = Theme.COLORS.text_primary
  local INACTIVE_TEXT = Theme.COLORS.text_secondary
  local DIVIDER_COLOR = Theme.COLORS.divider or { 0.15, 0.16, 0.22, 0.60 }

  -- Container anchored at the bottom of the contacts pane
  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetHeight(TAB_HEIGHT)
  frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

  -- Top divider line
  local divider = frame:CreateTexture(nil, "BACKGROUND")
  divider:SetHeight(1)
  divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  applyColorTexture(divider, DIVIDER_COLOR)

  -- Background fill
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
  bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  applyColorTexture(bg, INACTIVE_BG)

  -- Whispers button
  local whispersBtn = factory.CreateFrame("Button", nil, frame)
  whispersBtn:SetHeight(TAB_HEIGHT)
  whispersBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
  whispersBtn:SetPoint("TOPRIGHT", frame, "TOP", 0, -1)

  local whispersBg = whispersBtn:CreateTexture(nil, "BACKGROUND")
  whispersBg:SetAllPoints()
  applyColorTexture(whispersBg, INACTIVE_BG)

  local whispersLabel = whispersBtn:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  whispersLabel:SetPoint("CENTER", whispersBtn, "CENTER", 0, 0)
  whispersLabel:SetText(Localization.Text("Whispers"))
  UIHelpers.setTextColor(whispersLabel, INACTIVE_TEXT)

  -- Groups button
  local groupsBtn = factory.CreateFrame("Button", nil, frame)
  groupsBtn:SetHeight(TAB_HEIGHT)
  groupsBtn:SetPoint("TOPLEFT", frame, "TOP", 0, -1)
  groupsBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -1)

  local groupsBg = groupsBtn:CreateTexture(nil, "BACKGROUND")
  groupsBg:SetAllPoints()
  applyColorTexture(groupsBg, INACTIVE_BG)

  local groupsLabel = groupsBtn:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  groupsLabel:SetPoint("CENTER", groupsBtn, "CENTER", 0, 0)
  groupsLabel:SetText(Localization.Text("Groups"))
  UIHelpers.setTextColor(groupsLabel, INACTIVE_TEXT)

  -- Center divider between tabs
  local centerDivider = frame:CreateTexture(nil, "ARTWORK")
  centerDivider:SetWidth(1)
  centerDivider:SetPoint("TOP", frame, "TOP", 0, -1)
  centerDivider:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
  applyColorTexture(centerDivider, DIVIDER_COLOR)

  local whispersUnread = 0
  local groupsUnread = 0

  local whispersBadge = createBadge(factory, whispersBtn, whispersLabel)
  local groupsBadge = createBadge(factory, groupsBtn, groupsLabel)

  local function updateBadge(badge, count)
    local n = tonumber(count) or 0
    if n <= 0 then
      if badge.frame.Hide then
        badge.frame:Hide()
      end
      return
    end
    badge.label:SetText(n > 99 and "99+" or tostring(n))
    if badge.frame.Show then
      badge.frame:Show()
    end
  end

  local function paintTabs()
    local isWhispers = currentMode == "whispers"
    applyColorTexture(whispersBg, isWhispers and ACTIVE_BG or INACTIVE_BG)
    UIHelpers.setTextColor(whispersLabel, isWhispers and ACTIVE_TEXT or INACTIVE_TEXT)
    applyColorTexture(groupsBg, (not isWhispers) and ACTIVE_BG or INACTIVE_BG)
    UIHelpers.setTextColor(groupsLabel, (not isWhispers) and ACTIVE_TEXT or INACTIVE_TEXT)
    updateBadge(whispersBadge, whispersUnread)
    updateBadge(groupsBadge, groupsUnread)
  end

  paintTabs()

  local function setMode(mode)
    if mode ~= "whispers" and mode ~= "groups" then
      mode = "whispers"
    end
    currentMode = mode
    paintTabs()
  end

  local function getMode()
    return currentMode
  end

  if whispersBtn.SetScript then
    whispersBtn:SetScript("OnClick", function()
      if currentMode ~= "whispers" then
        setMode("whispers")
        onModeChanged("whispers")
      end
    end)
  end

  if groupsBtn.SetScript then
    groupsBtn:SetScript("OnClick", function()
      if currentMode ~= "groups" then
        setMode("groups")
        onModeChanged("groups")
      end
    end)
  end

  local function setShown(shown)
    if frame.SetShown then
      frame:SetShown(shown)
    elseif shown then
      if frame.Show then
        frame:Show()
      end
    else
      if frame.Hide then
        frame:Hide()
      end
    end
  end

  local function setUnreadCounts(whispersCount, groupsCount)
    whispersUnread = tonumber(whispersCount) or 0
    groupsUnread = tonumber(groupsCount) or 0
    paintTabs()
  end

  local function setLanguage()
    whispersLabel:SetText(Localization.Text("Whispers"))
    groupsLabel:SetText(Localization.Text("Groups"))
  end

  return {
    frame = frame,
    setMode = setMode,
    getMode = getMode,
    setShown = setShown,
    setUnreadCounts = setUnreadCounts,
    setLanguage = setLanguage,
    whispersBtn = whispersBtn,
    groupsBtn = groupsBtn,
    whispersLabel = whispersLabel,
    groupsLabel = groupsLabel,
    whispersBadge = whispersBadge.frame,
    groupsBadge = groupsBadge.frame,
  }
end

ns.ContactsListTabToggle = TabToggle
return TabToggle
