local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")

local Metrics = {}

function Metrics.ContactsSearchMetrics(theme)
  local resolvedTheme = theme or Theme
  local layout = resolvedTheme.LAYOUT or {}
  local searchHeight = layout.CONTACT_SEARCH_HEIGHT or 30
  local searchMargin = layout.CONTACT_SEARCH_MARGIN or 10
  local clearButtonSize = layout.CONTACT_SEARCH_CLEAR_BUTTON_SIZE or 18
  local totalHeight = searchHeight + (searchMargin * 2)

  return searchHeight, searchMargin, clearButtonSize, totalHeight
end

function Metrics.GetContactsResizeHandleWidth(theme)
  local resolvedTheme = theme or Theme
  local layout = resolvedTheme.LAYOUT or {}
  return layout.CONTACTS_RESIZE_HANDLE_WIDTH or 8
end

local function minContentWidth(resolvedTheme)
  local layout = resolvedTheme.LAYOUT or {}
  local defaultContactsWidth = resolvedTheme.CONTACTS_WIDTH or layout.CONTACTS_WIDTH or 300
  return layout.CONTENT_MIN_WIDTH
    or resolvedTheme.CONTENT_MIN_WIDTH
    or ((layout.WINDOW_MIN_WIDTH or resolvedTheme.WINDOW_MIN_WIDTH or 640) - defaultContactsWidth - (resolvedTheme.DIVIDER_THICKNESS or 1))
end

-- Clamp contacts pane width so users can resize it without collapsing the chat area.
-- windowWidth: overall window width
-- requestedContactsWidth: desired contacts pane width (or nil to use defaults)
-- theme: optional theme override for tests
-- collapsed: the pane shows as the rail; the expanded width it returns to is
--   kept whatever the window width (un-snapping grows the window to fit)
function Metrics.ClampContactsWidth(windowWidth, requestedContactsWidth, theme, collapsed)
  local resolvedTheme = theme or Theme
  local layout = resolvedTheme.LAYOUT or {}
  local dividerThickness = resolvedTheme.DIVIDER_THICKNESS or 1
  local defaultContactsWidth = resolvedTheme.CONTACTS_WIDTH or layout.CONTACTS_WIDTH or 300
  local minContactsWidth = layout.CONTACTS_MIN_WIDTH or resolvedTheme.CONTACTS_MIN_WIDTH or 180

  local safeWindowWidth = type(windowWidth) == "number" and windowWidth or (resolvedTheme.WINDOW_WIDTH or 920)
  local maxContactsWidth = math.max(minContactsWidth, safeWindowWidth - dividerThickness - minContentWidth(resolvedTheme))
  local nextWidth = type(requestedContactsWidth) == "number" and requestedContactsWidth or defaultContactsWidth

  if nextWidth < minContactsWidth then
    nextWidth = minContactsWidth
  end
  if nextWidth > maxContactsWidth and not collapsed then
    nextWidth = maxContactsWidth
  end

  return nextWidth
end

function Metrics.RailWidth(theme)
  local layout = (theme or Theme).LAYOUT or {}
  return layout.CONTACTS_RAIL_WIDTH or 46
end

-- Snap state for a divider drag to requestedWidth: the expanded pane
-- collapses to the rail below the collapse point, the rail expands past the
-- expand point, and in between it keeps its current state.
function Metrics.NextCollapsed(collapsed, requestedWidth, theme)
  local layout = (theme or Theme).LAYOUT or {}
  if collapsed then
    return requestedWidth <= (layout.CONTACTS_RAIL_EXPAND_ABOVE or 125)
  end
  return requestedWidth < (layout.CONTACTS_RAIL_COLLAPSE_BELOW or 110)
end

-- Window width an un-snapped pane of expandedWidth needs beside the chat.
function Metrics.ExpandedWindowWidth(expandedWidth, theme)
  local resolvedTheme = theme or Theme
  local layout = resolvedTheme.LAYOUT or {}
  local needed = expandedWidth + (resolvedTheme.DIVIDER_THICKNESS or 1) + minContentWidth(resolvedTheme)
  return math.max(layout.WINDOW_MIN_WIDTH or resolvedTheme.WINDOW_MIN_WIDTH or 640, needed)
end

function Metrics.CalculateRelayout(layoutState, width, height, requestedContactsWidth, theme)
  local resolvedTheme = theme or Theme
  local layout = resolvedTheme.LAYOUT or {}

  local collapsed = layoutState.contactsCollapsed == true
  local expandedContactsWidth = Metrics.ClampContactsWidth(
    width,
    requestedContactsWidth or layoutState.expandedContactsWidth or layoutState.contactsWidth,
    resolvedTheme,
    collapsed
  )
  -- Settings nav keeps the expanded width (as far as the window allows) so it
  -- stays readable while the contacts pane is the rail.
  local optionsMenuWidth = collapsed and Metrics.ClampContactsWidth(width, expandedContactsWidth, resolvedTheme) or expandedContactsWidth
  -- With settings open the pane lays out at the nav width, so what is pinned
  -- to it (the Modern HUD panel border, the divider and its handle) lines up
  -- with the nav instead of standing at the rail edge across it.
  local contactsWidth = optionsMenuWidth
  if collapsed and not layoutState.optionsVisible then
    contactsWidth = Metrics.RailWidth(resolvedTheme)
  end
  -- Native WoW HUD content area is smaller than the frame by the template
  -- border and title bar (single-anchored divider/handle take this height).
  local hudInsets = layoutState.nativeChrome and Hud.ContentInsets(layout)
  local contactsHeight = hudInsets and (height - hudInsets.top - hudInsets.bottom) or (height - resolvedTheme.TOP_BAR_HEIGHT)
  local contentWidth = width - contactsWidth - resolvedTheme.DIVIDER_THICKNESS
  -- Options content column: HUD fills the content area; modern keeps its
  -- 10px-per-side margin.
  local optionsContentWidth
  if hudInsets then
    -- The HUD conversation pane sits inside the template border too, so the
    -- transcript and composer lay out at the pane's real width.
    contentWidth = contentWidth - hudInsets.left - hudInsets.right
    -- The options page also clears the panel's right border (and sits
    -- beside the settings nav, which is wider than the rail).
    optionsContentWidth = contentWidth - (optionsMenuWidth - contactsWidth) - (layout.HUD_PANEL_PADDING or 0)
  else
    optionsContentWidth = (width - 20) - optionsMenuWidth - resolvedTheme.DIVIDER_THICKNESS
  end
  local contentHeight = contactsHeight
  local threadHeight = contentHeight - resolvedTheme.COMPOSER_HEIGHT - resolvedTheme.DIVIDER_THICKNESS

  local searchHeight = layoutState.contactsSearchHeight or (layout.CONTACT_SEARCH_HEIGHT or 30)
  local searchMargin = layoutState.contactsSearchMargin or (layout.CONTACT_SEARCH_MARGIN or 10)
  local searchTotalHeight = layoutState.contactsSearchTotalHeight or (searchHeight + (searchMargin * 2))
  -- The tabs hang below the window, so only the HUD reserves space under
  -- the list: it clears the panel's bottom border.
  local contactsBottomInset = hudInsets and layout.HUD_PANEL_PADDING or 0
  local contactsListHeight = math.max(0, contactsHeight - searchTotalHeight - contactsBottomInset)

  return {
    windowWidth = width,
    contactsWidth = contactsWidth,
    expandedContactsWidth = expandedContactsWidth,
    optionsMenuWidth = optionsMenuWidth,
    contactsHeight = contactsHeight,
    contentWidth = contentWidth,
    optionsContentWidth = optionsContentWidth,
    contentHeight = contentHeight,
    threadHeight = threadHeight,
    searchHeight = searchHeight,
    searchMargin = searchMargin,
    searchTotalHeight = searchTotalHeight,
    contactsBottomInset = contactsBottomInset,
    contactsListHeight = contactsListHeight,
  }
end

ns.MessengerWindowLayoutMetrics = Metrics

return Metrics
