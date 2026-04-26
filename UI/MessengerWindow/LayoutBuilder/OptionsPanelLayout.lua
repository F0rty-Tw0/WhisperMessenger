local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local OptionsPanelLayout = {}

function OptionsPanelLayout.Build(factory, frame, initialState, options)
  options = options or {}

  local theme = options.theme or Theme
  local contactsWidth = options.contactsWidth
  local scrollView = options.scrollView or ScrollView
  local applyTexture = options.applyColorTexture or applyColorTexture

  -- Same 20px top offset under both chromes — only the chrome itself is
  -- conditional on Azeroth, layout sizes/positions stay uniform.
  -- Dual-anchor BOTTOMRIGHT so the panel auto-fills the parent's full width
  -- (Inset for Azeroth, outer frame for modern) — matches the messenger
  -- window width in both chromes without needing explicit SetSize.
  local optionsPanel = factory.CreateFrame("Frame", nil, frame)
  -- Flush left/right against the parent via dual-anchor offsets. No SetSize —
  -- the anchors auto-derive full width and height (parent.height - 28).
  -- SetSize would override the BOTTOMRIGHT anchor with the OUTER frame width
  -- (which is wider than Inset under Azeroth), causing overflow past the
  -- gold border.
  optionsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -20)
  optionsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 5)

  -- Dual-anchor menu vertically to optionsPanel so it auto-fills the
  -- panel's height (no stale TOP_BAR_HEIGHT-based SetSize). Width stays
  -- explicit (the contacts column width).
  local optionsMenu = factory.CreateFrame("Frame", nil, optionsPanel)
  optionsMenu:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 0, 0)
  optionsMenu:SetPoint("BOTTOMLEFT", optionsPanel, "BOTTOMLEFT", 0, 0)
  optionsMenu:SetWidth(contactsWidth)

  local optionsMenuBg = optionsMenu:CreateTexture(nil, "BACKGROUND")
  optionsMenuBg:SetAllPoints(optionsMenu)
  applyTexture(optionsMenuBg, theme.COLORS.bg_secondary)

  local menuPadding = theme.CONTENT_PADDING

  local optionsHeader = optionsMenu:CreateFontString(nil, "OVERLAY", theme.FONTS.header_name)
  optionsHeader:SetPoint("TOPLEFT", optionsMenu, "TOPLEFT", menuPadding, -menuPadding)
  optionsHeader:SetText("Options")

  local optionsMenuDivider = optionsPanel:CreateTexture(nil, "BORDER")
  optionsMenuDivider:SetPoint("TOPLEFT", optionsMenu, "TOPRIGHT", 0, 0)
  optionsMenuDivider:SetPoint("BOTTOMLEFT", optionsMenu, "BOTTOMRIGHT", 0, 0)
  optionsMenuDivider:SetWidth(theme.DIVIDER_THICKNESS)
  applyTexture(optionsMenuDivider, theme.COLORS.divider)

  -- Dual-anchor content pane to fill the right portion of optionsPanel
  -- (between the menu's right edge and optionsPanel's bottom-right). No
  -- SetSize — anchors derive width and height from the parent's size,
  -- which itself follows optionsPanel's dual-anchor to the messenger.
  local optionsContentPane = factory.CreateFrame("Frame", nil, optionsPanel)
  optionsContentPane:SetPoint("TOPLEFT", optionsMenu, "TOPRIGHT", theme.DIVIDER_THICKNESS, -2)
  optionsContentPane:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -4, 0)
  -- Initial width/height as a fallback for environments that don't resolve
  -- anchors (fake_ui in tests). In production WoW, the dual-anchor wins.
  local optionsContentWidth = initialState.width - contactsWidth - theme.DIVIDER_THICKNESS - 4
  local optionsContentH = initialState.height - theme.TOP_BAR_HEIGHT - 28 - 2
  optionsContentPane:SetSize(optionsContentWidth, optionsContentH)

  local optionsContentBg = optionsContentPane:CreateTexture(nil, "BACKGROUND")
  optionsContentBg:SetAllPoints(optionsContentPane)
  applyTexture(optionsContentBg, theme.COLORS.bg_primary)

  -- Initial content height before the per-tab measurement (in
  -- WindowScripts/Buttons selectTab) runs. RefreshMetrics floors the
  -- effective height at the viewport, so this just needs to be large
  -- enough that the very first show — before the deferred remeasure
  -- lands — doesn't clip the active tab. Per-tab dynamic sizing takes
  -- over from there.
  local OPTIONS_CONTENT_HEIGHT = 800
  local optionsScrollView = scrollView.Create(factory, optionsContentPane, {
    width = optionsContentWidth,
    height = optionsContentH,
    step = 24,
  })
  optionsScrollView.content:SetSize(optionsContentWidth, OPTIONS_CONTENT_HEIGHT)

  -- The scrollview is built while the options panel is hidden, so its
  -- initial Sync captured a 0 viewport height (hasOverflow=false, scrollbar
  -- hidden, mouse wheel range=0). Re-Sync on Show so the cached geometry
  -- reflects the live scrollFrame. The tab-aware sizer in WindowScripts
  -- runs its own measurement on top of this via HookScript("OnShow").
  if optionsPanel.SetScript then
    optionsPanel:SetScript("OnShow", function()
      scrollView.Sync(optionsScrollView)
    end)
  end

  return {
    optionsPanel = optionsPanel,
    optionsMenu = optionsMenu,
    optionsMenuBg = optionsMenuBg,
    menuPadding = menuPadding,
    optionsHeader = optionsHeader,
    optionsMenuDivider = optionsMenuDivider,
    optionsContentPane = optionsContentPane,
    optionsContentBg = optionsContentBg,
    optionsScrollView = optionsScrollView,
    optionsContentHeight = OPTIONS_CONTENT_HEIGHT,
  }
end

ns.MessengerWindowLayoutOptionsPanelLayout = OptionsPanelLayout

return OptionsPanelLayout
