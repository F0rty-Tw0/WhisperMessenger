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
local applyColorTexture = UIHelpers.applyColorTexture

local TabToggle = {}

local TAB_HEIGHT = 24
-- Exported so layout code can reserve exactly this much space under the
-- contacts list while the toggle is shown.
TabToggle.HEIGHT = TAB_HEIGHT
-- Native WoW HUD strip height (Blizzard tab art).
TabToggle.NATIVE_HEIGHT = NativeTabToggle.HEIGHT
local UNDERLINE_HEIGHT = 2
-- Unread badge beside the label; SetSize keeps its digits readable.
local BADGE_SIZE = 14
local BADGE_GAP = 4
-- Underline overhang beyond the label+badge group (total, both sides).
local UNDERLINE_PADDING = 12
-- Footer: a faint white lift over the bar bg so the strip reads as
-- its own surface, distinct from the contact list above it.
local FOOTER_TINT = { 1, 1, 1, 0.04 }
local FALLBACK_DIVIDER = { 0.15, 0.16, 0.22, 0.60 }

-- One equal-width segment: button spanning the bar height between two
-- anchors, hover fill, centred label, accent underline, badge.
local function createTab(factory, frame, textKey, leftAnchor, rightAnchor)
  local btn = factory.CreateFrame("Button", nil, frame)
  btn:SetPoint("TOPLEFT", frame, leftAnchor, 0, -1)
  btn:SetPoint("BOTTOMRIGHT", frame, rightAnchor, 0, 0)

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

  local badge = Badge.Create(factory, btn, { size = BADGE_SIZE })
  badge.frame:SetPoint("LEFT", label, "RIGHT", BADGE_GAP, 0)

  return {
    btn = btn,
    hover = hover,
    hoverFade = HoverFade.Attach(hover),
    label = label,
    underline = underline,
    badge = badge,
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

local function labelColor(active, hovered)
  if active then
    return Theme.COLORS.accent
  end
  return hovered and Theme.COLORS.text_primary or Theme.COLORS.text_secondary
end

-- Segments sit on the footer surface; accent label + underline mark the
-- active one, hover brightens inactive ones with a faint fill.
local function paintTab(tab, active)
  tab.badge.paint()
  UIHelpers.setTextColor(tab.label, labelColor(active, tab.hovered))
  applyColorTexture(tab.underline, Theme.COLORS.accent_bar)
  tab.underline:SetShown(active)
  tab.hoverFade.paintColor(Theme.COLORS.bg_contact_hover)
  tab.hoverFade.set(tab.hovered and not active)
end

-- Create builds a two-segment Whispers/Groups toggle control anchored to
-- the bottom of the parent contacts pane.
--
-- options:
--   parent        : parent frame
--   initialMode   : "whispers" | "groups"  (default "whispers")
--   onModeChanged : function(mode)
--   nativeChrome  : Native WoW HUD -> Blizzard tabs at the pane bottom
--
-- Returns:
--   { frame, reservedHeight, setMode, getMode, setShown, setUnreadCounts, setLanguage }
function TabToggle.Create(factory, parent, options)
  options = options or {}
  if options.nativeChrome then
    local native = NativeTabToggle.Create(factory, parent, options)
    if native then
      return native
    end
  end
  local onModeChanged = options.onModeChanged or function(_mode) end
  local currentMode = options.initialMode or "whispers"

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

  -- Background fill
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
  bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

  -- Lift over the bg that turns the bar into a footer surface.
  local footerTint = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  footerTint:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
  footerTint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  footerTint:Show()

  local whispers = createTab(factory, frame, "Whispers", "TOPLEFT", "BOTTOM")
  local groups = createTab(factory, frame, "Groups", "TOP", "BOTTOMRIGHT")

  -- Colours are read at paint time so preset switches repaint on the
  -- next mode, unread, hover or language update.
  local function paintTabs()
    local isWhispers = currentMode == "whispers"
    applyColorTexture(divider, Theme.COLORS.divider or FALLBACK_DIVIDER)
    applyColorTexture(bg, Theme.COLORS.bg_primary or Theme.COLORS.bg_secondary)
    applyColorTexture(footerTint, FOOTER_TINT)
    for _, tab in ipairs({ whispers, groups }) do
      tab.badge.setCount(tab.unread)
      layoutGroup(tab)
    end
    paintTab(whispers, isWhispers)
    paintTab(groups, not isWhispers)
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

  local function bindTab(tab, mode)
    if not tab.btn.SetScript then
      return
    end
    tab.btn:SetScript("OnClick", function()
      if currentMode ~= mode then
        setMode(mode)
        onModeChanged(mode)
      end
    end)
    tab.btn:SetScript("OnEnter", function()
      tab.hovered = true
      paintTabs()
    end)
    tab.btn:SetScript("OnLeave", function()
      tab.hovered = false
      paintTabs()
    end)
  end
  bindTab(whispers, "whispers")
  bindTab(groups, "groups")

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
    whispers.unread = tonumber(whispersCount) or 0
    groups.unread = tonumber(groupsCount) or 0
    paintTabs()
  end

  local function setLanguage()
    whispers.label:SetText(Localization.Text(whispers.textKey))
    groups.label:SetText(Localization.Text(groups.textKey))
    paintTabs()
  end

  return {
    frame = frame,
    reservedHeight = TAB_HEIGHT,
    setMode = setMode,
    getMode = getMode,
    setShown = setShown,
    setUnreadCounts = setUnreadCounts,
    setLanguage = setLanguage,
  }
end

ns.ContactsListTabToggle = TabToggle
return TabToggle
