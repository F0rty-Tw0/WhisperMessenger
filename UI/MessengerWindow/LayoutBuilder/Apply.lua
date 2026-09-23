local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue

local Apply = {}

function Apply.Relayout(layout, relayout, theme)
  local resolvedTheme = theme or Theme
  local layoutTheme = resolvedTheme.LAYOUT or {}

  local contactsWidth = relayout.contactsWidth
  local contactsHeight = relayout.contactsHeight
  local contentWidth = relayout.contentWidth
  local contentHeight = relayout.contentHeight
  local threadHeight = relayout.threadHeight
  local searchHeight = relayout.searchHeight
  local searchMargin = relayout.searchMargin
  local searchTotalHeight = relayout.searchTotalHeight
  local contactsListHeight = relayout.contactsListHeight

  layout.contactsWidth = contactsWidth

  layout.contactsPane:SetSize(contactsWidth, contactsHeight)
  -- Re-anchor so the pane keeps its edge insets after every relayout.
  local contactsPaneParent = layout.contactsPane.GetParent and layout.contactsPane:GetParent() or layout.contactsPane.parent
  if contactsPaneParent and layout.contactsPane.ClearAllPoints then
    layout.contactsPane:ClearAllPoints()
    layout.contactsPane:SetPoint(
      "TOPLEFT",
      contactsPaneParent,
      "TOPLEFT",
      layoutTheme.CONTACTS_PANE_LEFT_INSET,
      layout.contactsTopOffset or -layoutTheme.TOP_BAR_HEIGHT
    )
    layout.contactsPane:SetPoint(
      "BOTTOMLEFT",
      contactsPaneParent,
      "BOTTOMLEFT",
      layoutTheme.CONTACTS_PANE_BOTTOM_LEFT_INSET,
      layoutTheme.CONTACTS_PANE_BOTTOM_INSET
    )
  end
  layout.contactsDivider:SetSize(UIHelpers.hairlineThickness(layout.contactsDivider, resolvedTheme.DIVIDER_THICKNESS), contactsHeight)
  if layout.contactsResizeHandle then
    local handleWidth =
      sizeValue(layout.contactsResizeHandle, "GetWidth", "width", layout.contactsHandleWidth or Theme.LAYOUT.CONTACTS_RESIZE_HANDLE_WIDTH)
    layout.contactsResizeHandle:SetSize(handleWidth, contactsHeight)
    if layout.contactsResizeHandle.ClearAllPoints then
      layout.contactsResizeHandle:ClearAllPoints()
    end
    layout.contactsResizeHandle:SetPoint("TOPLEFT", layout.contactsPane, "TOPRIGHT", -math.floor(handleWidth / 2), 0)
  end

  if layout.contactsSearchFrame then
    local insetX = resolvedTheme.LAYOUT.CONTACT_SEARCH_INSET_X or searchMargin
    layout.contactsSearchFrame:SetSize(math.max(0, contactsWidth - (insetX * 2)), searchHeight)
    if layout.contactsSearchFrame.ClearAllPoints then
      layout.contactsSearchFrame:ClearAllPoints()
    end
    layout.contactsSearchFrame:SetPoint("TOPLEFT", layout.contactsPane, "TOPLEFT", insetX, -searchMargin)
  end

  layout.contentPane:SetSize(contentWidth, contentHeight)
  if layout.contentPane.ClearAllPoints then
    layout.contentPane:ClearAllPoints()
  end
  layout.contentPane:SetPoint("TOPLEFT", layout.contactsPane, "TOPRIGHT", resolvedTheme.DIVIDER_THICKNESS, 0)
  -- Re-establish the dual-anchor so contentPane stays auto-sized to its
  -- parent after a resize. Without this the BOTTOMRIGHT anchor is lost on
  -- every relayout, height/width/margin collapse. Use :GetParent() in
  -- production WoW; fake_ui falls back to the stored .parent field.
  local contentParentForAnchor
  if layout.contactsPane then
    if type(layout.contactsPane.GetParent) == "function" then
      contentParentForAnchor = layout.contactsPane:GetParent()
    end
    if contentParentForAnchor == nil then
      contentParentForAnchor = layout.contactsPane.parent
    end
  end
  if contentParentForAnchor then
    layout.contentPane:SetPoint(
      "BOTTOMRIGHT",
      contentParentForAnchor,
      "BOTTOMRIGHT",
      -Theme.LAYOUT.CONTENT_PANE_RIGHT_INSET,
      Theme.LAYOUT.CONTENT_PANE_BOTTOM_INSET
    )
  end
  if layout.headerDivider then
    layout.headerDivider:SetSize(contentWidth, UIHelpers.hairlineThickness(layout.headerDivider, resolvedTheme.DIVIDER_THICKNESS))
  end
  layout.threadPane:SetSize(contentWidth, threadHeight)
  -- composerPane width tracks contentPane's *actual* current width (after
  -- contentPane's dual-anchor settles). Reading live geometry instead of
  -- `contentWidth` (the precomputed full content width) means the SetSize
  -- matches the dual-anchor in production WoW where contentPane is
  -- shorter than `contentWidth` by CONTENT_PANE_RIGHT_INSET.
  local contentPaneWidth = (layout.contentPane.GetWidth and layout.contentPane:GetWidth()) or layout.contentPane.width or contentWidth
  layout.composerPane:SetSize(contentPaneWidth, resolvedTheme.COMPOSER_HEIGHT)
  if layout.composerPane.ClearAllPoints then
    layout.composerPane:ClearAllPoints()
    layout.composerPane:SetPoint("BOTTOMLEFT", layout.contentPane, "BOTTOMLEFT", 0, 0)
    layout.composerPane:SetPoint("BOTTOMRIGHT", layout.contentPane, "BOTTOMRIGHT", 0, 0)
  end

  -- Resize contacts scroll view while preserving its content height and scroll position.
  local cv = layout.contactsView
  if cv then
    cv.totalWidth = contactsWidth
    if cv.scrollFrame.ClearAllPoints then
      cv.scrollFrame:ClearAllPoints()
    end
    -- SetSize keeps the calculated height in sync with layout metrics (and
    -- with our fake_ui harness, which doesn't derive size from anchors).
    -- The extra BOTTOMRIGHT anchor below is a WoW-only safety net: in the
    -- live client, dual-anchor pins the viewport to the pane regardless of
    -- any small mismatch between contactsListHeight and the pane's real
    -- dual-anchored height, so rows can't paint past the pane border.
    cv.scrollFrame:SetPoint("TOPLEFT", layout.contactsPane, "TOPLEFT", 0, -searchTotalHeight)
    cv.scrollFrame:SetSize(contactsWidth, contactsListHeight)
    cv.scrollFrame:SetPoint("BOTTOMRIGHT", layout.contactsPane, "BOTTOMRIGHT", 0, relayout.contactsBottomInset or 0)
    cv.scrollBar:SetHeight(contactsListHeight)
    cv.viewportHeight = contactsListHeight
    local Metrics = ns.ScrollViewMetrics or require("WhisperMessenger.UI.ScrollView.Metrics")
    Metrics.RefreshMetrics(cv, sizeValue(cv.content, "GetHeight", "height", contactsListHeight))
  end

  -- Resize options overlay to match new window dimensions. optionsPanel's
  -- size is fully driven by its dual-anchor (TOPLEFT + BOTTOMRIGHT to
  -- parent) — DON'T call SetSize on it, that would override the anchor
  -- with the outer windowWidth (which is wider than Inset under the HUD)
  -- and overflow the gold border.
  local optionsHeight = contactsHeight
  -- Inner content width (Metrics): options panel width minus the menu
  -- column + divider.
  local optionsContentWidth = relayout.optionsContentWidth
  layout.optionsMenu:SetSize(contactsWidth, optionsHeight)
  layout.optionsMenuDivider:SetSize(resolvedTheme.DIVIDER_THICKNESS, optionsHeight)
  layout.optionsContentPane:SetSize(optionsContentWidth, optionsHeight)
  layout.refreshOptionsMenuScrollGeometry()

  local menuPadding = layout.menuPadding or resolvedTheme.CONTENT_PADDING
  local optionsButtonWidth = math.max(0, contactsWidth - (menuPadding * 2))
  local optionsButtonHeight = layout.optionsButtonHeight or layoutTheme.OPTION_BUTTON_HEIGHT
  if layout.optionsHint then
    if layout.optionsHint.SetWidth then
      layout.optionsHint:SetWidth(optionsButtonWidth)
    end
    if layout.optionsHint.SetWordWrap then
      layout.optionsHint:SetWordWrap(true)
    end
    if layout.optionsHint.SetJustifyH then
      layout.optionsHint:SetJustifyH("LEFT")
    end
  end
  for _, button in ipairs({
    layout.generalTab,
    layout.appearanceTab,
    layout.behaviorTab,
    layout.notificationsTab,
    layout.iconsTab,
    layout.whatsNewTab,
    layout.resetWindowButton,
    layout.resetIconButton,
    layout.clearAllChatsButton,
  }) do
    if button and button.SetSize then
      button:SetSize(optionsButtonWidth, optionsButtonHeight)
    end
  end

  -- Resize options scroll view.
  local osv = layout.optionsScrollView
  if osv then
    osv.scrollFrame:SetSize(optionsContentWidth, optionsHeight)
    osv.scrollBar:SetHeight(optionsHeight)
    osv.viewportHeight = optionsHeight
    osv.totalWidth = optionsContentWidth
    local Metrics = ns.ScrollViewMetrics or require("WhisperMessenger.UI.ScrollView.Metrics")
    Metrics.RefreshMetrics(osv, sizeValue(osv.content, "GetHeight", "height", layout.optionsContentHeight or 420))
  end

  return {
    contactsWidth = contactsWidth,
    contentWidth = contentWidth,
    contactsHeight = contactsHeight,
    contactsListHeight = contactsListHeight,
    threadHeight = threadHeight,
  }
end

ns.MessengerWindowLayoutApply = Apply

return Apply
