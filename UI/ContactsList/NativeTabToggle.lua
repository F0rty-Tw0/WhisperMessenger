local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Badge = ns.Badge or require("WhisperMessenger.UI.Badge")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local TabLayout = ns.ContactsListTabLayout or require("WhisperMessenger.UI.ContactsList.TabLayout")
local TabScroller = ns.ContactsListTabScroller or require("WhisperMessenger.UI.ContactsList.TabScroller")
local TabArrows = ns.ContactsListTabArrows or require("WhisperMessenger.UI.ContactsList.TabArrows")

-- Native WoW HUD Whispers/Groups/Channels/Requests tabs: Blizzard PanelTabButtonTemplate
-- tabs hanging below the window's bottom-left edge, each sized to its label,
-- like the Character or Professions frame tabs. When they don't all fit,
-- TabScroller shows whole tabs with the spellbook page arrows at the strip's
-- two ends. The strip is the window's child (so it stays up beside an addon
-- panel) and anchored to the window frame. Same interface as TabToggle.Create; returns nil when the template is
-- unavailable so the caller builds the modern bar instead.
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
-- The badge sits on the tab's top-right corner, so tabs keep Blizzard's own
-- width (label + sides) and never widen for it.
local BADGE_SIZE = 14
-- Pulls the badge in from the corner so it sits over its own tab, not the gap.
local BADGE_CORNER_INSET = 4
-- The badge straddles the window's bottom edge, and the template's border art
-- (NineSlice) sits on a high frame level; the badge draws this far above it.
local BADGE_LEVEL_LIFT = 1
-- Retail's tab sides: a tab is label + this. Tabs size themselves because
-- Classic clients' PanelTemplates_TabResize adds both edge pieces on top of
-- label + 24 and caps only the label, making tabs about twice as wide.
local TAB_SIDES = 20
-- The last tab's right art reaches this far past its button; the scroller
-- keeps it free at the strip's right end.
local RIGHT_ART_OVERHANG = 7

-- Blizzard helpers vary per flavor; never let them error our UI.
local function callPanelTemplates(fnName, ...)
  local fn = _G[fnName]
  if type(fn) == "function" then
    pcall(fn, ...)
    return true
  end
  return false
end

local function regionWidth(region)
  return region and region.GetWidth and region:GetWidth() or 0
end

-- Label width plus the sides, never narrower than the left + right edge
-- art, which would overlap.
local function sizeTab(tab)
  local btn = tab.btn
  local label = btn.Text
  if label and label.SetWidth then
    label:SetWidth(0)
  end
  local textWidth = btn.GetTextWidth and btn:GetTextWidth() or 0
  local artWidth = regionWidth(btn.Left) + regionWidth(btn.Right)
  btn:SetWidth(math.max(textWidth + TAB_SIDES, artWidth))
end

local function liftAboveBorder(badgeFrame, window)
  local border = window and window.NineSlice or window
  if border and border.GetFrameLevel and badgeFrame.GetFrameLevel and badgeFrame.SetFrameLevel then
    -- Only ever raise it: a low border must not sink the badge under its tab.
    badgeFrame:SetFrameLevel(math.max(badgeFrame:GetFrameLevel(), border:GetFrameLevel() + BADGE_LEVEL_LIFT))
  end
end

-- The Requests badge is dim so a stranger's message never looks urgent.
-- label is shown as given; an addon panel tab has no mode.
local function createTab(factory, frame, window, name, label, mode)
  local btn = UIHelpers.createTemplatedFrame(factory, "Button", name, frame, TAB_TEMPLATE)
  if btn == nil then
    return nil
  end
  btn:SetText(label)
  local badge = Badge.Create(factory, btn, { size = BADGE_SIZE, outline = true, dim = mode == "requests" })
  badge.frame:SetPoint("CENTER", btn, "TOPRIGHT", -BADGE_CORNER_INSET, -BORDER_OVERLAP)
  liftAboveBorder(badge.frame, window)
  local tab = { btn = btn, badge = badge, mode = mode, unread = 0 }
  -- Replaces the template's OnShow / DISPLAY_SIZE_CHANGED handlers, which
  -- would re-run the flavor's own TabResize.
  local function resize()
    sizeTab(tab)
  end
  btn:SetScript("OnShow", resize)
  btn:SetScript("OnEvent", resize)
  resize()
  return tab
end

local function createModeTab(factory, frame, window, index, textKey, mode)
  local tab = createTab(factory, frame, window, TAB_NAMES[index], Localization.Text(textKey), mode)
  if tab then
    tab.textKey = textKey
  end
  return tab
end

local function paintBadges(tabs)
  for _, tab in ipairs(tabs) do
    tab.badge.setCount(tab.unread)
    tab.badge.paint()
  end
end

-- options.windowFrame: the frame the tabs hang from (default: parent).
function NativeTabToggle.Create(factory, parent, options)
  options = options or {}
  local window = options.windowFrame or parent

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetHeight(TAB_HEIGHT)
  frame:SetPoint("TOPLEFT", window, "BOTTOMLEFT", WINDOW_LEFT_OFFSET, BORDER_OVERLAP)
  frame:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, BORDER_OVERLAP)

  local whispers = createModeTab(factory, frame, window, 1, "Whispers", "whispers")
  local groups = whispers and createModeTab(factory, frame, window, 2, "Groups", "groups")
  local requests = groups and createModeTab(factory, frame, window, 3, "Requests", "requests")
  local channels = requests and createModeTab(factory, frame, window, 4, "Channels", "channels")
  if whispers == nil or groups == nil or requests == nil or channels == nil then
    frame:Hide()
    return nil
  end
  local tabs = { whispers, groups, requests, channels }
  local toggle = { frame = frame }
  local scroller = TabScroller.Attach(factory, frame, {
    spacing = TAB_SPACING,
    endReserve = RIGHT_ART_OVERHANG,
    arrowWidth = TabArrows.NATIVE_SIZE,
    createArrows = function(holder)
      return TabArrows.CreateNative(factory, holder)
    end,
  })

  local function paintTabs(currentMode, visible, selectedPanel, panelTabs)
    paintBadges(tabs)
    paintBadges(panelTabs)
    for _, tab in ipairs(visible) do
      local active = TabLayout.IsActive(tab, currentMode, selectedPanel)
      callPanelTemplates(active and "PanelTemplates_SelectTab" or "PanelTemplates_DeselectTab", tab.btn)
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
    -- Sizes the tabs; the scroller places them (all while they fit, else
    -- whole tabs from its scroll position, with the active one in view).
    anchor = function(visible, activeTab)
      for _, tab in ipairs(visible) do
        sizeTab(tab)
      end
      scroller.layout(visible, activeTab)
    end,
    createPanelTab = function(title, index)
      return createTab(factory, frame, window, "WhisperMessengerPanelTab" .. index, title, nil)
    end,
  })

  -- TabLayout applies the shown state through toggle.setShown, so the
  -- clamp follows it.
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
