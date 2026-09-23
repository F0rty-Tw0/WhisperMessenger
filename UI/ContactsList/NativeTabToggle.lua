local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Badge = ns.Badge or require("WhisperMessenger.UI.Badge")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- Native WoW HUD Whispers/Groups tabs: Blizzard PanelTabButtonTemplate tabs in
-- a strip at the bottom of the contacts pane (inside the window, so they are
-- never clipped or pushed off-screen). Same interface as TabToggle.Create;
-- returns nil when the template is unavailable so the caller builds the modern
-- bar instead.
local NativeTabToggle = {}

local TAB_TEMPLATE = "PanelTabButtonTemplate"
-- Global names: some clients' PanelTemplates_* look up _G[name .. "Left"].
local TAB_NAMES = { "WhisperMessengerTab1", "WhisperMessengerTab2" }
-- Tab art height; the contacts list reserves exactly this much.
local TAB_HEIGHT = 32
NativeTabToggle.HEIGHT = TAB_HEIGHT
local BADGE_SIZE = 14
local BADGE_INSET = 8
-- The tab template raises its own level (+4 on retail); stay clearly above it.
local LINE_LEVEL_OFFSET = 10

-- Blizzard helpers vary per flavor; never let them error our UI.
local function callPanelTemplates(fnName, ...)
  local fn = _G[fnName]
  if type(fn) == "function" then
    pcall(fn, ...)
  end
end

local function createTab(factory, frame, index, textKey)
  local btn = UIHelpers.createTemplatedFrame(factory, "Button", TAB_NAMES[index], frame, TAB_TEMPLATE)
  if btn == nil then
    return nil
  end
  btn:SetText(Localization.Text(textKey))
  local badge = Badge.Create(factory, btn, { size = BADGE_SIZE, outline = true })
  badge.frame:SetPoint("RIGHT", btn, "RIGHT", -BADGE_INSET, 0)
  return { btn = btn, badge = badge, textKey = textKey, unread = 0 }
end

function NativeTabToggle.Create(factory, parent, options)
  options = options or {}
  local onModeChanged = options.onModeChanged or function(_mode) end
  local currentMode = options.initialMode or "whispers"

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetHeight(TAB_HEIGHT)
  frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

  -- 1px lines: one along the strip top (separates it from the list) and one
  -- on the seam between the two tabs. Drawn on an overlay frame because the
  -- tab buttons render above any texture on the strip itself.
  local lineLayer = factory.CreateFrame("Frame", nil, frame)
  lineLayer:SetAllPoints(frame)
  lineLayer:SetFrameLevel(frame:GetFrameLevel() + LINE_LEVEL_OFFSET)
  local hairline = UIHelpers.hairlineThickness(frame, 1)

  local topLine = lineLayer:CreateTexture(nil, "OVERLAY")
  topLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  topLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  topLine:SetHeight(hairline)
  UIHelpers.snapToPixelGrid(topLine)

  local seamLine = lineLayer:CreateTexture(nil, "OVERLAY")
  seamLine:SetPoint("TOP", frame, "TOP", 0, 0)
  seamLine:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
  seamLine:SetWidth(hairline)
  UIHelpers.snapToPixelGrid(seamLine)

  local whispers = createTab(factory, frame, 1, "Whispers")
  local groups = whispers and createTab(factory, frame, 2, "Groups")
  if whispers == nil or groups == nil then
    frame:Hide()
    return nil
  end
  -- Two horizontal anchors give each tab half the strip. The template's own
  -- PanelTemplates_TabResize (OnShow) can't shrink an anchored width to 0.
  whispers.btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  whispers.btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", 0, 0)
  groups.btn:SetPoint("TOPLEFT", frame, "TOP", 0, 0)
  groups.btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  -- Lines use the vertical contacts divider's colour (same token + fallback),
  -- read at paint time so theme refreshes repaint them.
  local function paintTabs()
    local isWhispers = currentMode == "whispers"
    local lineColor = Theme.COLORS.contacts_divider or Theme.COLORS.divider
    UIHelpers.applyColorTexture(topLine, lineColor)
    UIHelpers.applyColorTexture(seamLine, lineColor)
    for _, tab in ipairs({ whispers, groups }) do
      tab.badge.setCount(tab.unread)
      tab.badge.paint()
    end
    callPanelTemplates(isWhispers and "PanelTemplates_SelectTab" or "PanelTemplates_DeselectTab", whispers.btn)
    callPanelTemplates(isWhispers and "PanelTemplates_DeselectTab" or "PanelTemplates_SelectTab", groups.btn)
  end

  local function setMode(mode)
    if mode ~= "whispers" and mode ~= "groups" then
      mode = "whispers"
    end
    currentMode = mode
    paintTabs()
  end

  for _, entry in ipairs({ { whispers, "whispers" }, { groups, "groups" } }) do
    local tab, mode = entry[1], entry[2]
    tab.btn:SetScript("OnClick", function()
      if currentMode ~= mode then
        setMode(mode)
        onModeChanged(mode)
      end
    end)
  end

  paintTabs()

  return {
    frame = frame,
    reservedHeight = TAB_HEIGHT,
    setMode = setMode,
    getMode = function()
      return currentMode
    end,
    setShown = function(shown)
      frame:SetShown(shown)
    end,
    setUnreadCounts = function(whispersCount, groupsCount)
      whispers.unread = tonumber(whispersCount) or 0
      groups.unread = tonumber(groupsCount) or 0
      paintTabs()
    end,
    setLanguage = function()
      whispers.btn:SetText(Localization.Text(whispers.textKey))
      groups.btn:SetText(Localization.Text(groups.textKey))
      paintTabs()
    end,
  }
end

ns.ContactsListNativeTabToggle = NativeTabToggle
return NativeTabToggle
