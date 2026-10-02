local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")
local Badge = ns.Badge or require("WhisperMessenger.UI.Badge")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local NativeTabToggle = ns.ContactsListNativeTabToggle or require("WhisperMessenger.UI.ContactsList.NativeTabToggle")
local TabLayout = ns.ContactsListTabLayout or require("WhisperMessenger.UI.ContactsList.TabLayout")
local applyColorTexture = UIHelpers.applyColorTexture

-- Whispers/Groups(/Requests) tabs. They hang below the window's bottom-left
-- edge, each at its natural width (like the game's own window tabs), so the
-- contact list keeps its full height. The Native WoW HUD uses Blizzard's tab
-- art (NativeTabToggle); the modern skin draws its own.
local TabToggle = {}

local TAB_HEIGHT = 24
-- How far the tabs hang below the window (the screen clamp includes it).
TabToggle.HEIGHT = TAB_HEIGHT
local UNDERLINE_HEIGHT = 2
-- Unread badge beside the label; SetSize keeps its digits readable.
local BADGE_SIZE = 14
local BADGE_GAP = 4
-- Underline overhang beyond the label+badge group (total, both sides).
local UNDERLINE_PADDING = 12
-- A faint white lift over each tab's surface so it reads as its own tab.
local SURFACE_TINT = { 1, 1, 1, 0.04 }
-- Inset from the window's left edge and the gap between neighbouring tabs.
local HANG_LEFT_OFFSET = 8
local HANG_SPACING = 2
local HANG_EDGES = { top = false, left = true, right = true, bottom = true }

-- One tab: hover fill, centred label, accent underline, badge, then its own
-- surface, tint and outline. The Requests badge is dim so a stranger's message never
-- looks urgent.
local function createTab(factory, frame, textKey, mode)
  local btn = factory.CreateFrame("Button", nil, frame)

  local hover = btn:CreateTexture(nil, "BORDER")
  hover:SetAllPoints()
  hover:Hide()

  local label = btn:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  label:SetPoint("CENTER", btn, "CENTER", 0, 0)
  label:SetText(Localization.Text(textKey))

  local underline = btn:CreateTexture(nil, "ARTWORK")
  underline:SetHeight(UNDERLINE_HEIGHT)
  underline:SetPoint("BOTTOM", btn, "BOTTOM", 0, 0)
  underline:Hide()

  local badge = Badge.Create(factory, btn, { size = BADGE_SIZE, dim = mode == "requests" })
  badge.frame:SetPoint("LEFT", label, "RIGHT", BADGE_GAP, 0)

  local surface = btn:CreateTexture(nil, "BACKGROUND")
  surface:SetAllPoints(btn)
  local tint = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
  tint:SetAllPoints(btn)
  -- Outlined like the window (same hairline helper and colour) on the
  -- left, right and bottom; the open top hangs from the window's edge.
  local border = UIHelpers.createBorderBox(btn, Theme.COLORS.window_border, Theme.LAYOUT.DIVIDER_THICKNESS, "OVERLAY", HANG_EDGES)

  return {
    mode = mode,
    btn = btn,
    hover = hover,
    hoverFade = HoverFade.Attach(hover),
    label = label,
    underline = underline,
    badge = badge,
    surface = surface,
    tint = tint,
    border = border,
    textKey = textKey,
    unread = 0,
    hovered = false,
  }
end

-- Center label + badge as one group; the underline spans that group.
-- Event-driven: runs on mode, unread-count, hover and language changes only.
local function layoutGroup(tab)
  local extra = tab.badge.frame:IsShown() and (BADGE_GAP + BADGE_SIZE) or 0
  local labelWidth = tab.label:GetStringWidth() or 0
  tab.label:SetPoint("CENTER", tab.btn, "CENTER", -extra / 2, 0)
  tab.underline:SetWidth(labelWidth + extra + UNDERLINE_PADDING)
end

-- Width a tab needs; the badge is always counted so tabs never shift with
-- unread counts.
local function naturalWidth(tab)
  return (tab.label:GetStringWidth() or 0) + BADGE_GAP + BADGE_SIZE + UNDERLINE_PADDING
end

local function labelColor(active, hovered)
  if active then
    return Theme.COLORS.accent
  end
  return hovered and Theme.COLORS.text_primary or Theme.COLORS.text_secondary
end

-- Accent label + underline mark the active tab, hover brightens inactive
-- ones with a faint fill. Colours are read at paint time so preset switches
-- repaint on the next mode, unread, hover or language update.
local function paintTab(tab, active)
  applyColorTexture(tab.surface, Theme.COLORS.bg_primary or Theme.COLORS.bg_secondary)
  applyColorTexture(tab.tint, SURFACE_TINT)
  UIHelpers.applyBorderBoxColor(tab.border, Theme.COLORS.window_border)
  tab.badge.setCount(tab.unread)
  layoutGroup(tab)
  tab.badge.paint()
  UIHelpers.setTextColor(tab.label, labelColor(active, tab.hovered))
  applyColorTexture(tab.underline, Theme.COLORS.accent_bar)
  tab.underline:SetShown(active)
  tab.hoverFade.paintColor(Theme.COLORS.bg_contact_hover)
  tab.hoverFade.set(tab.hovered and not active)
end

-- Visible tabs side by side from the strip's left edge.
local function chainTabs(frame, visible)
  local previous = nil
  for _, tab in ipairs(visible) do
    tab.btn:ClearAllPoints()
    tab.btn:SetSize(naturalWidth(tab), TAB_HEIGHT)
    if previous then
      tab.btn:SetPoint("TOPLEFT", previous.btn, "TOPRIGHT", HANG_SPACING, 0)
    else
      tab.btn:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    end
    previous = tab
  end
end

-- options:
--   initialMode   : "whispers" | "groups" | "requests" (default "whispers")
--   onModeChanged : function(mode)
--   nativeChrome  : Native WoW HUD -> Blizzard tab art
--   windowFrame   : the window the tabs hang from (default: parent)
--
-- The strip is parented to `parent` (the contacts pane) so it hides with it.
-- Returns:
--   { frame, setMode, getMode, setModes, setShown, setUnreadCounts, setLanguage }
function TabToggle.Create(factory, parent, options)
  options = options or {}
  if options.nativeChrome then
    local native = NativeTabToggle.Create(factory, parent, options)
    if native then
      return native
    end
  end
  local window = options.windowFrame or parent
  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetHeight(TAB_HEIGHT)
  frame:SetPoint("TOPLEFT", window, "BOTTOMLEFT", HANG_LEFT_OFFSET, 0)
  frame:SetPoint("TOPRIGHT", window, "BOTTOMRIGHT", 0, 0)

  local byMode = {
    whispers = createTab(factory, frame, "Whispers", "whispers"),
    groups = createTab(factory, frame, "Groups", "groups"),
    requests = createTab(factory, frame, "Requests", "requests"),
  }
  local toggle = { frame = frame }

  local paintTabs = TabLayout.BindController(toggle, frame, byMode, {
    initialMode = options.initialMode,
    onModeChanged = options.onModeChanged,
    paint = function(currentMode)
      for _, mode in ipairs(TabLayout.MODES) do
        paintTab(byMode[mode], mode == currentMode)
      end
    end,
    relabel = function(tab)
      tab.label:SetText(Localization.Text(tab.textKey))
    end,
    anchor = function(visible)
      chainTabs(frame, visible)
    end,
  })

  for _, mode in ipairs(TabLayout.MODES) do
    local tab = byMode[mode]
    tab.btn:SetScript("OnEnter", function()
      tab.hovered = true
      paintTabs()
    end)
    tab.btn:SetScript("OnLeave", function()
      tab.hovered = false
      paintTabs()
    end)
  end

  -- ContactsRuntime always calls setShown after Create.
  local applyClamp = TabLayout.BindClamp(window, TAB_HEIGHT)
  local setShown = toggle.setShown
  toggle.setShown = function(shown)
    setShown(shown)
    applyClamp(shown)
  end
  return toggle
end

ns.ContactsListTabToggle = TabToggle
return TabToggle
