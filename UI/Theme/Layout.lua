local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Layout = {
  WINDOW_WIDTH = 900,
  WINDOW_HEIGHT = 580,
  WINDOW_MIN_WIDTH = 480,
  WINDOW_MIN_HEIGHT = 320,
  CONTACTS_WIDTH = 300,
  CONTACTS_MIN_WIDTH = 180,
  CONTENT_MIN_WIDTH = 340,
  CONTACTS_RESIZE_HANDLE_WIDTH = 8,
  TOP_BAR_HEIGHT = 24,
  CONTENT_PADDING = 16,
  COMPOSER_HEIGHT = 44,
  DIVIDER_THICKNESS = 1,

  -- Contacts search
  CONTACT_SEARCH_HEIGHT = 30,
  -- The search field floats inside the pane with a gap above the first row.
  CONTACT_SEARCH_MARGIN = 6,
  -- Horizontal inset of the search field (vertical gap uses the margin above).
  CONTACT_SEARCH_INSET_X = 4,
  CONTACT_SEARCH_CLEAR_BUTTON_SIZE = 18,

  -- Contact rows
  CONTACT_ROW_HEIGHT = 48,
  CONTACT_ICON_SIZE = 34,
  CONTACT_FACTION_SIZE = 14,
  CONTACT_STATUS_SIZE = 10,
  CONTACT_PADDING = 6,
  CONTACT_ACCENT_BAR_W = 2,
  -- Right column: time (~10) + 2 + pin 14 + 2 + remove 14 fits 48.
  CONTACT_ACTION_SIZE = 14,
  -- Name label top / preview bottom offsets relative to the class icon.
  CONTACT_NAME_OFFSET_Y = 1,
  CONTACT_PREVIEW_OFFSET_Y = -1,
  CONTACT_ACTION_SPACING = 4,

  -- Chat bubbles
  BUBBLE_MAX_WIDTH_PCT = 0.75,
  BUBBLE_PADDING_H = 12,
  BUBBLE_PADDING_V = 8,
  BUBBLE_SPACING = 4,
  BUBBLE_GROUP_SPACING = 12,
  BUBBLE_ICON_SIZE = 24,
  MESSAGE_EDGE_INSET = 32,
  BUBBLE_ICON_GAP = 8,

  -- Date separators
  DATE_SEPARATOR_HEIGHT = 28,

  -- Scrollbar
  SCROLLBAR_WIDTH = 4,
  SCROLLBAR_WIDTH_HOVER = 6,
  SCROLLBAR_THUMB_MIN_H = 20,

  -- Composer
  -- One gutter on every side (input height is the strip
  -- minus both gutters), square buttons centered on the input, equal gaps.
  COMPOSER_GUTTER = 8,
  COMPOSER_BUTTON_SIZE = 26,
  COMPOSER_BUTTON_GAP = 4,

  -- Toggle icon
  ICON_SIZE = 42,
  ICON_BADGE_SIZE = 20,

  -- Header
  HEADER_HEIGHT = 56,
  HEADER_ICON_SIZE = 32,
  -- Gap between the class icon and the name / status text.
  HEADER_NAME_GAP = 10,
  HEADER_STATUS_DOT_SIZE = 8,

  -- Conversation pane transcript
  TRANSCRIPT_HORIZONTAL_INSET = 32,
  TRANSCRIPT_LEFT_GUTTER = 16,

  -- Window chrome buttons (close / new conversation / options / empty-state)
  CHROME_BUTTON_SIZE = 20,
  CHROME_BUTTON_ICON_SIZE = 14,
  -- Custom title bar: one hit size and gap for every button; the edge inset
  -- puts the outer glyphs' ink 8px from the window edge on both sides.
  TITLE_BUTTON_SIZE = 22,
  TITLE_BUTTON_GAP = 4,
  TITLE_BAR_INSET_X = 3,

  -- Pane insets from the window edge (shared between initial Build and
  -- Relayout). The 1px window hairline is a BORDER texture on the
  -- window frame, so child panes would paint over it; inset by exactly 1.
  CONTACTS_PANE_LEFT_INSET = 1,
  CONTACTS_PANE_BOTTOM_LEFT_INSET = 1,
  CONTACTS_PANE_BOTTOM_INSET = 1,
  CONTENT_PANE_RIGHT_INSET = 1,
  CONTENT_PANE_BOTTOM_INSET = 1,
  -- Native WoW HUD: edges of the template's inset background (top edge is
  -- TOP_BAR_HEIGHT), plus the inset border width. Content sits inside both.
  HUD_INSET_LEFT = 4,
  HUD_INSET_RIGHT = 6,
  HUD_INSET_BOTTOM = 4,
  -- ponytail: assumed border width, not read from the template; tune in-game.
  HUD_CONTENT_INSET = 3,
  -- Top edge only, below TOP_BAR_HEIGHT (negative = tucks up under the
  -- title bar border). ponytail: tuned in-game from a screenshot.
  HUD_CONTENT_TOP_INSET = -1,

  -- Status dot corner offset over icon (header + contact row)
  STATUS_DOT_CORNER_OFFSET = 2,

  -- Option buttons
  OPTION_BUTTON_HEIGHT = 30,
  OPTION_BUTTON_SPACING = 8,

  -- Settings panels (shared across Appearance/General/Behavior/Notification)
  SETTINGS_CONTROL_WIDTH = 350,
  SETTINGS_SLIDER_HEIGHT = 16,
  SETTINGS_LABEL_SPACING = 6,
  SETTINGS_SLIDER_ROW_SPACING = 32,
  SETTINGS_TOGGLE_ROW_SPACING = 16,

  -- Misc
  MESSAGE_TIMESTAMP_GAP = 6,
}

ns.ThemeLayout = Layout
return Layout
