local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")
local applyColorTexture = UIHelpers.applyColorTexture
local sizeValue = UIHelpers.sizeValue

local OptionsPanelLayout = {}

-- The Retail HUD covers the window's rough backdrop with the smooth panel
-- art (`atlas`, default the list one); other HUD styles keep the pane
-- clear, modern paints `color`.
local function paintPane(texture, nativeChrome, color, applyTexture, atlas)
  if nativeChrome and Hud.IsRetail() and NativeArt.PaintPanel(texture, atlas) then
    return
  end
  applyTexture(texture, nativeChrome and UIHelpers.TRANSPARENT or color)
end

function OptionsPanelLayout.Build(factory, frame, initialState, options)
  options = options or {}

  local theme = options.theme or Theme
  local contactsWidth = options.contactsWidth
  local scrollView = options.scrollView or ScrollView
  local applyTexture = options.applyColorTexture or applyColorTexture
  -- Native WoW HUD: `frame` is the chrome's content area, which already
  -- clears the title bar, so the panel sits flush and viewports take the
  -- content-area height (options.contactsHeight).
  local nativeChrome = options.nativeChrome == true

  -- Same 20px top offset under both chromes — only the chrome itself is
  -- conditional on the Native WoW HUD setting, layout sizes/positions stay
  -- uniform. Dual-anchor BOTTOMRIGHT so the panel auto-fills the parent's
  -- full width (Inset for the HUD, outer frame otherwise) — matches the messenger
  -- window width in both chromes without needing explicit SetSize.
  local optionsPanel = factory.CreateFrame("Frame", nil, frame)
  -- Flush left/right against the parent via dual-anchor offsets. No SetSize —
  -- the anchors auto-derive full width and height (parent.height - 28).
  -- SetSize would override the BOTTOMRIGHT anchor with the OUTER frame width
  -- (which is wider than Inset under the HUD), causing overflow past the
  -- gold border.
  -- Native WoW HUD: clear of the panel borders the game draws inside.
  local hudPadding = nativeChrome and theme.LAYOUT.HUD_PANEL_PADDING or 0
  if nativeChrome then
    optionsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -hudPadding)
    optionsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, hudPadding)
  else
    optionsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -20)
    optionsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 5)
  end

  -- Dual-anchor menu vertically to optionsPanel so it auto-fills the
  -- panel's height (no stale TOP_BAR_HEIGHT-based SetSize). Width stays
  -- explicit (the contacts column width).
  local optionsMenu = factory.CreateFrame("Frame", nil, optionsPanel)
  optionsMenu:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 0, 0)
  optionsMenu:SetPoint("BOTTOMLEFT", optionsPanel, "BOTTOMLEFT", 0, 0)
  optionsMenu:SetWidth(contactsWidth)

  local optionsMenuBg = optionsMenu:CreateTexture(nil, "BACKGROUND")
  optionsMenuBg:SetAllPoints(optionsMenu)
  paintPane(optionsMenuBg, nativeChrome, theme.COLORS.bg_secondary, applyTexture)

  local menuPadding = theme.CONTENT_PADDING
  -- Set once the nav buttons exist (OptionsMenuButtons contentHeight).
  local measureMenuContent = nil
  -- The HUD panel sits hudPadding inside the content area at top and bottom.
  local nativePanelHeight = nativeChrome and options.contactsHeight and (options.contactsHeight - 2 * hudPadding)
  local optionsMenuViewportHeight = nativePanelHeight or (initialState.height - theme.TOP_BAR_HEIGHT)
  local optionsMenuScrollView = scrollView.Create(factory, optionsMenu, {
    width = contactsWidth,
    height = optionsMenuViewportHeight,
    step = 24,
  })
  if optionsMenuScrollView.scrollBar.ClearAllPoints then
    optionsMenuScrollView.scrollBar:ClearAllPoints()
  end
  optionsMenuScrollView.scrollBar:SetPoint("TOPRIGHT", optionsMenu, "TOPRIGHT", -hudPadding, 0)

  local function refreshOptionsMenuScrollGeometry()
    local menuWidth = sizeValue(optionsMenu, "GetWidth", "width", contactsWidth)
    local menuHeight = sizeValue(optionsMenu, "GetHeight", "height", optionsMenuViewportHeight)
    local menuContentHeight = math.max(menuHeight, measureMenuContent and measureMenuContent() or 0)

    optionsMenuScrollView.totalWidth = menuWidth
    optionsMenuScrollView.viewportHeight = menuHeight
    optionsMenuScrollView.hasOverflow = false
    optionsMenuScrollView.scrollFrame:SetSize(menuWidth, menuHeight)
    optionsMenuScrollView.content:SetSize(menuWidth, menuContentHeight)
    optionsMenuScrollView.scrollBar:SetHeight(menuHeight)
    scrollView.RefreshMetrics(optionsMenuScrollView, menuContentHeight)
  end

  refreshOptionsMenuScrollGeometry()

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
  -- Native WoW HUD: flush to the content area on top and right.
  local contentTopGap = nativeChrome and 0 or 2
  local contentRightInset = nativeChrome and hudPadding or 4
  optionsContentPane:SetPoint("TOPLEFT", optionsMenu, "TOPRIGHT", theme.DIVIDER_THICKNESS, -contentTopGap)
  optionsContentPane:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -contentRightInset, 0)
  -- Initial width/height as a fallback for environments that don't resolve
  -- anchors (fake_ui in tests). In production WoW, the dual-anchor wins.
  -- The scroll view's width also comes from here (single-anchored).
  local optionsContentWidth = nativeChrome and options.optionsContentWidth or (initialState.width - contactsWidth - theme.DIVIDER_THICKNESS - 4)
  local optionsContentH = nativePanelHeight or (initialState.height - theme.TOP_BAR_HEIGHT - 28 - 2)
  optionsContentPane:SetSize(optionsContentWidth, optionsContentH)

  local optionsContentBg = optionsContentPane:CreateTexture(nil, "BACKGROUND")
  optionsContentBg:SetAllPoints(optionsContentPane)
  paintPane(optionsContentBg, nativeChrome, theme.COLORS.bg_primary, applyTexture, NativeArt.WIDE_PANEL_BACKGROUND)

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
      refreshOptionsMenuScrollGeometry()
      scrollView.Sync(optionsScrollView)
    end)
  end

  return {
    optionsPanel = optionsPanel,
    optionsMenu = optionsMenu,
    optionsMenuBg = optionsMenuBg,
    menuPadding = menuPadding,
    optionsMenuScrollView = optionsMenuScrollView,
    setMenuContentMeasure = function(measure)
      measureMenuContent = measure
    end,
    refreshOptionsMenuScrollGeometry = refreshOptionsMenuScrollGeometry,
    optionsMenuDivider = optionsMenuDivider,
    optionsContentPane = optionsContentPane,
    optionsContentBg = optionsContentBg,
    optionsScrollView = optionsScrollView,
    optionsContentHeight = OPTIONS_CONTENT_HEIGHT,
  }
end

ns.MessengerWindowLayoutOptionsPanelLayout = OptionsPanelLayout

return OptionsPanelLayout
