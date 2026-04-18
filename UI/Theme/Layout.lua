local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Layout = {
  WINDOW_WIDTH = 900,
  WINDOW_HEIGHT = 580,
  WINDOW_MIN_WIDTH = 480,
  WINDOW_MIN_HEIGHT = 420,
  CONTACTS_WIDTH = 300,
  CONTACTS_MIN_WIDTH = 180,
  CONTENT_MIN_WIDTH = 340,
  CONTACTS_RESIZE_HANDLE_WIDTH = 8,
  TOP_BAR_HEIGHT = 24,
  CONTENT_PADDING = 16,
  COMPOSER_HEIGHT = 52,
  DIVIDER_THICKNESS = 1,

  -- Contacts search
  CONTACT_SEARCH_HEIGHT = 30,
  CONTACT_SEARCH_MARGIN = 0,
  CONTACT_SEARCH_CLEAR_BUTTON_SIZE = 18,

  -- Contact rows
  CONTACT_ROW_HEIGHT = 56,
  CONTACT_ICON_SIZE = 40,
  CONTACT_FACTION_SIZE = 14,
  CONTACT_STATUS_SIZE = 10,
  CONTACT_PADDING = 6,
  CONTACT_ACCENT_BAR_W = 3,
  CONTACT_ACTION_SIZE = 20,
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
  COMPOSER_INPUT_HEIGHT = 36,

  -- Toggle icon
  ICON_SIZE = 42,
  ICON_BADGE_SIZE = 20,

  -- Header
  HEADER_HEIGHT = 56,
  HEADER_ICON_SIZE = 32,
  HEADER_STATUS_DOT_SIZE = 8,

  -- Conversation pane transcript
  TRANSCRIPT_HORIZONTAL_INSET = 32,
  TRANSCRIPT_LEFT_GUTTER = 16,

  -- Window chrome buttons (close / new conversation / options / empty-state)
  CHROME_BUTTON_SIZE = 20,
  CHROME_BUTTON_ICON_SIZE = 14,

  -- Content pane insets (shared between initial Build and Relayout)
  CONTENT_PANE_RIGHT_INSET = 5,
  CONTENT_PANE_BOTTOM_INSET = 10,

  -- Status dot corner offset over icon (header + contact row)
  STATUS_DOT_CORNER_OFFSET = 2,

  -- Option buttons
  OPTION_BUTTON_HEIGHT = 30,
  OPTION_BUTTON_SPACING = 8,
  OPTION_BUTTON_RADIUS = 4,

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
