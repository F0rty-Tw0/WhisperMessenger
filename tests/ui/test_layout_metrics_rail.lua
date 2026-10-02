local Metrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local Theme = require("WhisperMessenger.UI.Theme")

local L = Theme.LAYOUT

return function()
  local railWidth = Metrics.RailWidth(Theme)

  local collapseBelow = L.CONTACTS_RAIL_COLLAPSE_BELOW
  local expandAbove = L.CONTACTS_RAIL_EXPAND_ABOVE

  -- test_rail_fits_the_contact_icon_with_padding
  assert(railWidth == L.CONTACTS_RAIL_WIDTH, "rail width comes from the theme")
  assert(railWidth > L.CONTACT_ICON_SIZE, "rail is wider than the contact icon")

  -- test_snap_points_leave_a_hysteresis_gap
  assert(collapseBelow < expandAbove, "collapse point sits below the expand point")
  assert(expandAbove < L.CONTACTS_MIN_WIDTH, "both sit below the expanded minimum")

  -- test_expanded_pane_holds_until_below_the_collapse_point
  assert(Metrics.NextCollapsed(false, collapseBelow, Theme) == false, "at the collapse point the pane stays expanded")
  assert(Metrics.NextCollapsed(false, collapseBelow - 1, Theme) == true, "below it the pane snaps to the rail")

  -- test_rail_holds_until_past_the_expand_point
  assert(Metrics.NextCollapsed(true, expandAbove, Theme) == true, "rail holds up to the expand point")
  assert(Metrics.NextCollapsed(true, expandAbove + 1, Theme) == false, "rail expands past it")

  -- test_jitter_between_the_points_never_flips
  assert(Metrics.NextCollapsed(true, (collapseBelow + expandAbove) / 2, Theme) == true, "rail stays in the gap")
  assert(Metrics.NextCollapsed(false, (collapseBelow + expandAbove) / 2, Theme) == false, "expanded stays in the gap")

  -- test_collapsed_layout_uses_the_rail_width_and_keeps_the_expanded_width
  do
    local m = Metrics.CalculateRelayout({ contactsCollapsed = true }, 900, 560, 300, Theme)
    assert(m.contactsWidth == railWidth, "collapsed pane is rail wide, got " .. tostring(m.contactsWidth))
    assert(m.expandedContactsWidth == 300, "expanded width is kept, got " .. tostring(m.expandedContactsWidth))
    assert(m.contentWidth == 900 - railWidth - Theme.DIVIDER_THICKNESS, "content takes the freed width, got " .. tostring(m.contentWidth))
  end

  -- test_collapsed_expanded_width_ignores_a_narrow_window
  do
    local m = Metrics.CalculateRelayout({ contactsCollapsed = true }, 400, 560, 300, Theme)
    assert(m.expandedContactsWidth == 300, "a narrow collapsed window must not shrink the expanded width, got " .. tostring(m.expandedContactsWidth))
  end

  -- test_collapsed_layout_without_request_reuses_the_stored_expanded_width
  do
    local m = Metrics.CalculateRelayout({ contactsCollapsed = true, contactsWidth = railWidth, expandedContactsWidth = 260 }, 900, 560, nil, Theme)
    assert(m.expandedContactsWidth == 260, "a resize keeps the stored expanded width, got " .. tostring(m.expandedContactsWidth))
  end

  -- test_settings_nav_keeps_the_expanded_width_while_collapsed
  do
    local m = Metrics.CalculateRelayout({ contactsCollapsed = true }, 900, 560, 300, Theme)
    assert(m.optionsMenuWidth == 300, "settings nav uses the expanded width, got " .. tostring(m.optionsMenuWidth))
    assert(m.optionsContentWidth == (900 - 20) - 300 - Theme.DIVIDER_THICKNESS, "settings content sits beside the expanded nav")
  end

  -- test_settings_open_lay_a_collapsed_pane_out_at_the_nav_width
  do
    local m = Metrics.CalculateRelayout({ contactsCollapsed = true, optionsVisible = true }, 400, 560, 300, Theme)
    assert(m.contactsWidth == m.optionsMenuWidth, "pane matches the settings nav, got " .. tostring(m.contactsWidth))
    assert(m.expandedContactsWidth == 300, "a narrow window still keeps the expanded width, got " .. tostring(m.expandedContactsWidth))
  end

  -- test_expanded_layout_is_unchanged
  do
    local m = Metrics.CalculateRelayout({}, 900, 560, 300, Theme)
    assert(m.contactsWidth == 300 and m.expandedContactsWidth == 300 and m.optionsMenuWidth == 300, "expanded widths all match")
  end

  -- test_clamp_skips_the_window_limit_while_collapsed
  assert(Metrics.ClampContactsWidth(400, 300, Theme, true) == 300, "collapsed clamp keeps the expanded width")
  assert(Metrics.ClampContactsWidth(400, 100, Theme, true) == L.CONTACTS_MIN_WIDTH, "collapsed clamp still honours the minimum")

  -- test_window_width_that_fits_the_expanded_pane
  assert(
    Metrics.ExpandedWindowWidth(300, Theme) == 300 + Theme.DIVIDER_THICKNESS + L.CONTENT_MIN_WIDTH,
    "un-snapping needs room for the pane, divider and minimum content"
  )
  assert(Metrics.ExpandedWindowWidth(100, Theme) == L.WINDOW_MIN_WIDTH, "never below the window minimum")
end
