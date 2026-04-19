local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local TabToggle = {}

local TAB_HEIGHT = 24
local TAB_PADDING_H = 8

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

  local parentWidth = UIHelpers.sizeValue(parent, "GetWidth", "width", 260)

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

  local halfW = math.floor(parentWidth / 2)

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
  whispersLabel:SetText("Whispers")
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
  groupsLabel:SetText("Groups")
  UIHelpers.setTextColor(groupsLabel, INACTIVE_TEXT)

  -- Center divider between tabs
  local centerDivider = frame:CreateTexture(nil, "ARTWORK")
  centerDivider:SetWidth(1)
  centerDivider:SetPoint("TOP", frame, "TOP", 0, -1)
  centerDivider:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
  applyColorTexture(centerDivider, DIVIDER_COLOR)

  local whispersUnread = 0
  local groupsUnread = 0

  local function formatTabLabel(base, count)
    local n = tonumber(count) or 0
    if n <= 0 then
      return base
    end
    return base .. " (" .. tostring(n) .. ")"
  end

  local function paintTabs()
    local isWhispers = currentMode == "whispers"
    applyColorTexture(whispersBg, isWhispers and ACTIVE_BG or INACTIVE_BG)
    UIHelpers.setTextColor(whispersLabel, isWhispers and ACTIVE_TEXT or INACTIVE_TEXT)
    applyColorTexture(groupsBg, (not isWhispers) and ACTIVE_BG or INACTIVE_BG)
    UIHelpers.setTextColor(groupsLabel, (not isWhispers) and ACTIVE_TEXT or INACTIVE_TEXT)
    whispersLabel:SetText(formatTabLabel("Whispers", whispersUnread))
    groupsLabel:SetText(formatTabLabel("Groups", groupsUnread))
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

  return {
    frame = frame,
    setMode = setMode,
    getMode = getMode,
    setShown = setShown,
    setUnreadCounts = setUnreadCounts,
    whispersBtn = whispersBtn,
    groupsBtn = groupsBtn,
    whispersLabel = whispersLabel,
    groupsLabel = groupsLabel,
  }
end

ns.ContactsListTabToggle = TabToggle
return TabToggle
