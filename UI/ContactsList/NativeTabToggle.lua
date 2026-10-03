local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Badge = ns.Badge or require("WhisperMessenger.UI.Badge")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local TabLayout = ns.ContactsListTabLayout or require("WhisperMessenger.UI.ContactsList.TabLayout")

-- Native WoW HUD Whispers/Groups/Channels/Requests tabs: Blizzard PanelTabButtonTemplate
-- tabs hanging below the window's bottom-left edge, each sized to its label,
-- like the Character or Professions frame tabs. The strip is parented to the
-- contacts pane (so it hides with it) but anchored to the window frame. Same
-- interface as TabToggle.Create; returns nil when the template is unavailable
-- so the caller builds the modern bar instead.
local NativeTabToggle = {}

local TAB_TEMPLATE = "PanelTabButtonTemplate"
-- Global names: some clients' PanelTemplates_* look up _G[name .. "Left"].
local TAB_NAMES = { "WhisperMessengerTab1", "WhisperMessengerTab2", "WhisperMessengerTab3", "WhisperMessengerTab4" }
local TAB_HEIGHT = 32
NativeTabToggle.HEIGHT = TAB_HEIGHT
-- Blizzard's own tab anchors (CharacterFrameTab1/2): 11px in from the
-- window's bottom-left, tab tops overlap the bottom border by 2px, 1px apart.
local WINDOW_LEFT_OFFSET = 11
local BORDER_OVERLAP = 2
local TAB_SPACING = 1
-- How far the tabs reach below the window; the screen clamp must include it.
local HANG_HEIGHT = TAB_HEIGHT - BORDER_OVERLAP
local BADGE_SIZE = 14
local BADGE_INSET = 8
-- Extra width beyond the label. Retail's PanelTemplates_TabResize adds 20px
-- of sides on top, so each side keeps (20 + 28) / 2 = 24px: room for the badge
-- at the right inset (8 + 14) without touching the centred label.
local TAB_PADDING = 28
-- Width without PanelTemplates_TabResize: label + retail sides + padding.
local FALLBACK_SIDES = 20

-- Blizzard helpers vary per flavor; never let them error our UI.
local function callPanelTemplates(fnName, ...)
  local fn = _G[fnName]
  if type(fn) == "function" then
    pcall(fn, ...)
    return true
  end
  return false
end

-- The template's OnShow re-runs TabResize with the parent's tabPadding.
local function sizeTab(tab)
  if not callPanelTemplates("PanelTemplates_TabResize", tab.btn, TAB_PADDING) then
    local textWidth = tab.btn.GetTextWidth and tab.btn:GetTextWidth() or 0
    tab.btn:SetWidth(textWidth + FALLBACK_SIDES + TAB_PADDING)
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
  local tab = { btn = btn, badge = badge, textKey = textKey, mode = mode, unread = 0 }
  sizeTab(tab)
  return tab
end

-- Visible tabs in a row from the strip's left edge, Blizzard spacing.
local function chainTabs(frame, visible)
  local previous = nil
  for _, tab in ipairs(visible) do
    tab.btn:ClearAllPoints()
    if previous then
      tab.btn:SetPoint("TOPLEFT", previous.btn, "TOPRIGHT", TAB_SPACING, 0)
    else
      tab.btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    end
    previous = tab
  end
end

-- options.windowFrame: the frame the tabs hang from (default: parent).
function NativeTabToggle.Create(factory, parent, options)
  options = options or {}
  local window = options.windowFrame or parent

  local frame = factory.CreateFrame("Frame", nil, parent)
  -- Read by the template's OnShow / DISPLAY_SIZE_CHANGED resize.
  frame.tabPadding = TAB_PADDING
  frame:SetHeight(TAB_HEIGHT)
  frame:SetPoint("TOPLEFT", window, "BOTTOMLEFT", WINDOW_LEFT_OFFSET, BORDER_OVERLAP)
  frame:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, BORDER_OVERLAP)

  local whispers = createTab(factory, frame, 1, "Whispers", "whispers")
  local groups = whispers and createTab(factory, frame, 2, "Groups", "groups")
  local requests = groups and createTab(factory, frame, 3, "Requests", "requests")
  local channels = requests and createTab(factory, frame, 4, "Channels", "channels")
  if whispers == nil or groups == nil or requests == nil or channels == nil then
    frame:Hide()
    return nil
  end
  local tabs = { whispers, groups, requests, channels }
  local toggle = { frame = frame }

  local function paintTabs(currentMode, visible)
    for _, tab in ipairs(tabs) do
      tab.badge.setCount(tab.unread)
      tab.badge.paint()
    end
    for _, tab in ipairs(visible) do
      callPanelTemplates(tab.mode == currentMode and "PanelTemplates_SelectTab" or "PanelTemplates_DeselectTab", tab.btn)
    end
  end

  TabLayout.BindController(toggle, frame, { whispers = whispers, groups = groups, channels = channels, requests = requests }, {
    initialMode = options.initialMode,
    onModeChanged = options.onModeChanged,
    paint = paintTabs,
    relabel = function(tab)
      tab.btn:SetText(Localization.Text(tab.textKey))
      sizeTab(tab)
    end,
    anchor = function(visible)
      chainTabs(frame, visible)
    end,
  })

  -- ContactsRuntime always calls setShown after Create.
  local applyClamp = TabLayout.BindClamp(window, HANG_HEIGHT)
  local setShown = toggle.setShown
  toggle.setShown = function(shown)
    setShown(shown)
    applyClamp(shown)
  end
  return toggle
end

ns.ContactsListNativeTabToggle = NativeTabToggle
return NativeTabToggle
