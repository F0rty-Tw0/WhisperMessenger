local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Badge = ns.Badge or require("WhisperMessenger.UI.Badge")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local TabLayout = ns.ContactsListTabLayout or require("WhisperMessenger.UI.ContactsList.TabLayout")

-- Native WoW HUD Whispers/Groups tabs: Blizzard PanelTabButtonTemplate tabs in
-- a strip at the bottom of the contacts pane (inside the window, so they are
-- never clipped or pushed off-screen). Same interface as TabToggle.Create;
-- returns nil when the template is unavailable so the caller builds the modern
-- bar instead.
local NativeTabToggle = {}

local TAB_TEMPLATE = "PanelTabButtonTemplate"
-- Global names: some clients' PanelTemplates_* look up _G[name .. "Left"].
local TAB_NAMES = { "WhisperMessengerTab1", "WhisperMessengerTab2", "WhisperMessengerTab3" }
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

-- The Requests badge is dim so a stranger's message never looks urgent.
local function createTab(factory, frame, index, textKey, mode)
  local btn = UIHelpers.createTemplatedFrame(factory, "Button", TAB_NAMES[index], frame, TAB_TEMPLATE)
  if btn == nil then
    return nil
  end
  btn:SetText(Localization.Text(textKey))
  local badge = Badge.Create(factory, btn, { size = BADGE_SIZE, outline = true, dim = mode == "requests" })
  badge.frame:SetPoint("RIGHT", btn, "RIGHT", -BADGE_INSET, 0)
  return { btn = btn, badge = badge, textKey = textKey, mode = mode, unread = 0 }
end

-- Width a tab needs on one row. The label is centred and the badge sits at
-- the right inset, so reserve badge room on both sides; the badge is always
-- counted so the wrap decision never flips with unread counts.
local function naturalWidth(tab)
  local textWidth = tab.btn.GetTextWidth and tab.btn:GetTextWidth() or 0
  return textWidth + 2 * (BADGE_INSET + BADGE_SIZE)
end

function NativeTabToggle.Create(factory, parent, options)
  options = options or {}

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetHeight(TAB_HEIGHT)
  frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

  -- 1px lines: one along the strip top (separates it from the list) and one
  -- on each seam between tabs. Drawn on an overlay frame because the tab
  -- buttons render above any texture on the strip itself.
  local lineLayer = factory.CreateFrame("Frame", nil, frame)
  lineLayer:SetAllPoints(frame)
  lineLayer:SetFrameLevel(frame:GetFrameLevel() + LINE_LEVEL_OFFSET)
  local hairline = UIHelpers.hairlineThickness(frame, 1)

  local topLine = lineLayer:CreateTexture(nil, "OVERLAY")
  topLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  topLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  topLine:SetHeight(hairline)
  UIHelpers.snapToPixelGrid(topLine)

  local seams = {}
  local function ensureSeam(index)
    if seams[index] == nil then
      local seam = lineLayer:CreateTexture(nil, "OVERLAY")
      seam:SetWidth(hairline)
      UIHelpers.snapToPixelGrid(seam)
      seams[index] = seam
    end
    return seams[index]
  end
  ensureSeam(1)

  local whispers = createTab(factory, frame, 1, "Whispers", "whispers")
  local groups = whispers and createTab(factory, frame, 2, "Groups", "groups")
  local requests = groups and createTab(factory, frame, 3, "Requests", "requests")
  if whispers == nil or groups == nil or requests == nil then
    frame:Hide()
    return nil
  end
  local tabs = { whispers, groups, requests }
  local toggle = { frame = frame }

  -- Two tabs share one seam at the strip centre; three tabs put a seam on
  -- the left edge of the second and third tab (seam 2 is created the first
  -- time three tabs show). Wrapped, only the top row has a seam.
  local function anchorSeams(wrapped, visible)
    local first = seams[1]
    first:ClearAllPoints()
    if wrapped then
      first:SetPoint("TOP", visible[2].btn, "TOPLEFT", 0, 0)
      first:SetPoint("BOTTOM", visible[2].btn, "BOTTOMLEFT", 0, 0)
      if seams[2] then
        seams[2]:Hide()
      end
      return
    end
    if #visible == 3 then
      first:SetPoint("TOP", visible[2].btn, "TOPLEFT", 0, 0)
      first:SetPoint("BOTTOM", visible[2].btn, "BOTTOMLEFT", 0, 0)
      local second = ensureSeam(2)
      second:ClearAllPoints()
      second:SetPoint("TOP", visible[3].btn, "TOPLEFT", 0, 0)
      second:SetPoint("BOTTOM", visible[3].btn, "BOTTOMLEFT", 0, 0)
      second:Show()
      return
    end
    first:SetPoint("TOP", frame, "TOP", 0, 0)
    first:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    if seams[2] then
      seams[2]:Hide()
    end
  end

  -- Lines use the vertical contacts divider's colour (same token + fallback),
  -- read at paint time so theme refreshes repaint them.
  local function paintTabs(currentMode, visible)
    local lineColor = Theme.COLORS.contacts_divider or Theme.COLORS.divider
    UIHelpers.applyColorTexture(topLine, lineColor)
    for _, seam in ipairs(seams) do
      UIHelpers.applyColorTexture(seam, lineColor)
    end
    for _, tab in ipairs(tabs) do
      tab.badge.setCount(tab.unread)
      tab.badge.paint()
    end
    for _, tab in ipairs(visible) do
      callPanelTemplates(tab.mode == currentMode and "PanelTemplates_SelectTab" or "PanelTemplates_DeselectTab", tab.btn)
    end
  end

  -- Two-point anchors give each tab an explicit width, so the template's
  -- own PanelTemplates_TabResize (OnShow) can't shrink it to 0.
  TabLayout.BindController(toggle, frame, { whispers = whispers, groups = groups, requests = requests }, {
    initialMode = options.initialMode,
    onModeChanged = options.onModeChanged,
    tabHeight = TAB_HEIGHT,
    topInset = 0,
    naturalWidth = naturalWidth,
    paint = paintTabs,
    relabel = function(tab)
      tab.btn:SetText(Localization.Text(tab.textKey))
    end,
    afterAnchor = anchorSeams,
  })
  return toggle
end

ns.ContactsListNativeTabToggle = NativeTabToggle
return NativeTabToggle
