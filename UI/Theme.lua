local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = {}

-- Legacy flat constants (preserved for backward compatibility)
Theme.TITLE = "WhisperMessenger"
Theme.WINDOW_IDLE_ALPHA = 1
Theme.WINDOW_EXTERNAL_ACTIVITY_ALPHA = 0.72
Theme.WINDOW_ALPHA_FADE_SECONDS = 0.12
Theme.WINDOW_ALPHA_UPDATE_INTERVAL = 0.1

---------------------------------------------------------------------------
-- Semantic color palette
---------------------------------------------------------------------------
Theme.COLORS = {
  bg_primary            = { 0.07, 0.07, 0.10, 0.97 },
  bg_secondary          = { 0.10, 0.10, 0.14, 0.60 },
  bg_bubble_in          = { 0.12, 0.13, 0.18, 0.80 },
  bg_bubble_out         = { 0.15, 0.38, 0.55, 0.80 },
  bg_bubble_system      = { 0.14, 0.12, 0.10, 0.65 },
  bg_composer           = { 0.09, 0.09, 0.13, 0.60 },
  bg_header             = { 0.08, 0.08, 0.12, 0.60 },
  bg_contact_hover      = { 0.14, 0.15, 0.22, 0.70 },
  bg_contact_selected   = { 0.16, 0.18, 0.28, 0.80 },
  bg_input              = { 0.12, 0.12, 0.16, 0.70 },
  text_primary          = { 0.92, 0.92, 0.95, 1.0 },
  text_secondary        = { 0.55, 0.55, 0.62, 1.0 },
  text_sent             = { 0.95, 0.95, 0.98, 1.0 },
  text_received         = { 0.88, 0.88, 0.92, 1.0 },
  text_system           = { 0.65, 0.58, 0.40, 1.0 },
  text_timestamp        = { 0.45, 0.45, 0.52, 1.0 },
  accent                = { 0.20, 0.55, 0.95, 1.0 },
  online                = { 0.30, 0.82, 0.40, 1.0 },
  offline               = { 0.45, 0.45, 0.50, 1.0 },
  away                  = { 0.90, 0.72, 0.20, 1.0 },
  dnd                   = { 0.85, 0.25, 0.25, 1.0 },
  unread_badge          = { 0.90, 0.25, 0.25, 1.0 },
  divider               = { 0.15, 0.16, 0.22, 0.60 },
  scrollbar             = { 0.35, 0.35, 0.42, 0.50 },
  scrollbar_hover       = { 0.45, 0.45, 0.52, 0.70 },
  accent_bar            = { 0.20, 0.55, 0.95, 1.0 },
  send_button           = { 0.20, 0.55, 0.95, 1.0 },
  send_button_hover     = { 0.28, 0.62, 1.00, 1.0 },
  send_button_disabled  = { 0.25, 0.25, 0.30, 0.60 },
  icon_bg               = { 0.18, 0.50, 0.95, 0.95 },
  badge_bg              = { 0.90, 0.25, 0.25, 0.95 },
}

---------------------------------------------------------------------------
-- Font templates (WoW built-in)
---------------------------------------------------------------------------
Theme.FONTS = {
  contact_name     = "GameFontNormal",
  contact_preview  = "GameFontDisableSmall",
  contact_time     = "GameFontDisableSmall",
  message_text     = "GameFontHighlight",
  message_time     = "GameFontDisableSmall",
  header_name      = "GameFontHighlightLarge",
  header_status    = "GameFontDisableSmall",
  date_separator   = "GameFontDisableSmall",
  system_text      = "GameFontHighlightSmall",
  unread_badge     = "GameFontHighlightSmall",
  composer_input   = "ChatFontNormal",
  icon_label       = "GameFontHighlight",
  empty_state      = "GameFontHighlight",
}

---------------------------------------------------------------------------
-- Layout dimensions
---------------------------------------------------------------------------
Theme.LAYOUT = {
  WINDOW_WIDTH           = 920,
  WINDOW_HEIGHT          = 580,
  WINDOW_MIN_WIDTH       = 640,
  WINDOW_MIN_HEIGHT      = 420,
  CONTACTS_WIDTH         = 300,
  TOP_BAR_HEIGHT         = 56,
  CONTENT_PADDING        = 16,
  COMPOSER_HEIGHT        = 52,
  DIVIDER_THICKNESS      = 1,

  -- Contact rows
  CONTACT_ROW_HEIGHT     = 64,
  CONTACT_ICON_SIZE      = 40,
  CONTACT_FACTION_SIZE   = 14,
  CONTACT_STATUS_SIZE    = 10,
  CONTACT_PADDING        = 12,
  CONTACT_ACCENT_BAR_W   = 3,

  -- Chat bubbles
  BUBBLE_MAX_WIDTH_PCT   = 0.75,
  BUBBLE_PADDING_H       = 12,
  BUBBLE_PADDING_V       = 8,
  BUBBLE_SPACING         = 4,
  BUBBLE_GROUP_SPACING   = 12,
  BUBBLE_ICON_SIZE       = 24,

  -- Date separators
  DATE_SEPARATOR_HEIGHT  = 28,

  -- Scrollbar
  SCROLLBAR_WIDTH        = 4,
  SCROLLBAR_WIDTH_HOVER  = 6,
  SCROLLBAR_THUMB_MIN_H  = 20,

  -- Composer
  COMPOSER_INPUT_HEIGHT  = 36,
  SEND_BUTTON_SIZE       = 36,

  -- Toggle icon
  ICON_SIZE              = 42,
  ICON_BADGE_SIZE        = 20,

  -- Header
  HEADER_ICON_SIZE       = 32,
  HEADER_STATUS_DOT_SIZE = 8,

  -- Misc
  MESSAGE_TIMESTAMP_GAP  = 6,
}

-- Backward-compatible flat aliases so existing code keeps working
Theme.WINDOW_WIDTH      = Theme.LAYOUT.WINDOW_WIDTH
Theme.WINDOW_HEIGHT     = Theme.LAYOUT.WINDOW_HEIGHT
Theme.CONTACTS_WIDTH    = Theme.LAYOUT.CONTACTS_WIDTH
Theme.TOP_BAR_HEIGHT    = Theme.LAYOUT.TOP_BAR_HEIGHT
Theme.CONTENT_PADDING   = Theme.LAYOUT.CONTENT_PADDING
Theme.COMPOSER_HEIGHT   = Theme.LAYOUT.COMPOSER_HEIGHT
Theme.DIVIDER_THICKNESS = Theme.LAYOUT.DIVIDER_THICKNESS

---------------------------------------------------------------------------
-- WoW atlas texture paths
---------------------------------------------------------------------------
Theme.TEXTURES = {
  class_icon_prefix  = "Interface\\ICONS\\ClassIcon_",
  faction_alliance   = "Interface\\ICONS\\PVPCurrency-Honor-Alliance",
  faction_horde      = "Interface\\ICONS\\PVPCurrency-Honor-Horde",
  bnet_icon          = "Interface\\FriendsFrame\\UI-Toast-ChatInviteIcon",
}

--- Map classTag to atlas icon path
function Theme.ClassIcon(classTag)
  if not classTag or classTag == "" then return nil end
  return Theme.TEXTURES.class_icon_prefix .. classTag
end

--- Map factionName to atlas icon path
function Theme.FactionIcon(factionName)
  if factionName == "Alliance" then
    return Theme.TEXTURES.faction_alliance
  elseif factionName == "Horde" then
    return Theme.TEXTURES.faction_horde
  end
  return nil
end

ns.Theme = Theme

return Theme
