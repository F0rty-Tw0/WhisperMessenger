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
  if layout.contactsRightBorder then
    layout.contactsRightBorder:SetHeight(contactsHeight)
  end
  layout.contactsDivider:SetSize(resolvedTheme.DIVIDER_THICKNESS, contactsHeight)
  if layout.contactsResizeHandle then
    local handleWidth = sizeValue(
      layout.contactsResizeHandle,
      "GetWidth",
      "width",
      layout.contactsHandleWidth or Theme.LAYOUT.CONTACTS_RESIZE_HANDLE_WIDTH
    )
    layout.contactsResizeHandle:SetSize(handleWidth, contactsHeight)
    if layout.contactsResizeHandle.ClearAllPoints then
      layout.contactsResizeHandle:ClearAllPoints()
    end
    layout.contactsResizeHandle:SetPoint("TOPLEFT", layout.contactsPane, "TOPRIGHT", -math.floor(handleWidth / 2), 0)
  end

  if layout.contactsSearchFrame then
    layout.contactsSearchFrame:SetSize(math.max(0, contactsWidth - (searchMargin * 2)), searchHeight)
    if layout.contactsSearchFrame.ClearAllPoints then
      layout.contactsSearchFrame:ClearAllPoints()
    end
    layout.contactsSearchFrame:SetPoint("TOPLEFT", layout.contactsPane, "TOPLEFT", searchMargin, -searchMargin)
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
  if layout.contactsHeaderDivider then
    layout.contactsHeaderDivider:SetSize(contactsWidth, resolvedTheme.DIVIDER_THICKNESS)
  end
  if layout.headerDivider then
    layout.headerDivider:SetSize(contentWidth, resolvedTheme.DIVIDER_THICKNESS)
  end
  layout.threadPane:SetSize(contentWidth, threadHeight)
  -- composerPane width tracks contentPane's *actual* current width (after
  -- contentPane's dual-anchor settles). Reading live geometry instead of
  -- `contentWidth` (the precomputed full content width) means the SetSize
  -- matches the dual-anchor in production WoW where contentPane is 5px
  -- shorter than `contentWidth` due to its own BOTTOMRIGHT (-5, 5) margin.
  local contentPaneWidth = (layout.contentPane.GetWidth and layout.contentPane:GetWidth())
    or layout.contentPane.width
    or contentWidth
  layout.composerPane:SetSize(contentPaneWidth, resolvedTheme.COMPOSER_HEIGHT)
  layout.composerDivider:SetSize(contentWidth, resolvedTheme.DIVIDER_THICKNESS)

  -- Resize contacts scroll view while preserving its content height and scroll position.
  local cv = layout.contactsView
  if cv then
    cv.totalWidth = contactsWidth
    if cv.scrollFrame.ClearAllPoints then
      cv.scrollFrame:ClearAllPoints()
    end
    cv.scrollFrame:SetPoint("TOPLEFT", layout.contactsPane, "TOPLEFT", 0, -searchTotalHeight)
    cv.scrollFrame:SetSize(contactsWidth, contactsListHeight)
    cv.scrollBar:SetHeight(contactsListHeight)
    cv.viewportHeight = contactsListHeight
    local Metrics = ns.ScrollViewMetrics or require("WhisperMessenger.UI.ScrollView.Metrics")
    Metrics.RefreshMetrics(cv, sizeValue(cv.content, "GetHeight", "height", contactsListHeight))
  end

  -- Resize options overlay to match new window dimensions. optionsPanel's
  -- size is fully driven by its dual-anchor (TOPLEFT + BOTTOMRIGHT to
  -- parent) — DON'T call SetSize on it, that would override the anchor
  -- with the outer windowWidth (which is wider than Inset under Azeroth)
  -- and overflow the gold border.
  local optionsHeight = contactsHeight
  local windowWidth = relayout.windowWidth
  -- Inner content width matches the shrunk options panel (windowWidth - 20
  -- for the 10px each side margin) minus the menu column + divider.
  local optionsContentWidth = (windowWidth - 20) - contactsWidth - resolvedTheme.DIVIDER_THICKNESS
  layout.optionsMenu:SetSize(contactsWidth, optionsHeight)
  layout.optionsMenuDivider:SetSize(resolvedTheme.DIVIDER_THICKNESS, optionsHeight)
  layout.optionsContentPane:SetSize(optionsContentWidth, optionsHeight)

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
