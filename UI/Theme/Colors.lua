local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Colors = {
  bg_primary = { 0.07, 0.07, 0.10, 0.97 },
  bg_secondary = { 0.10, 0.10, 0.14, 0.60 },
  bg_bubble_in = { 0.18, 0.21, 0.30, 0.92 },
  bg_bubble_out = { 0.15, 0.38, 0.55, 0.80 },
  bg_bubble_system = { 0.14, 0.12, 0.10, 0.65 },
  bg_composer = { 0.09, 0.09, 0.13, 0.60 },
  bg_header = { 0.08, 0.08, 0.12, 0.60 },
  bg_contact_hover = { 0.14, 0.15, 0.22, 0.70 },
  bg_contact_pinned = { 0.14, 0.13, 0.10, 0.72 },
  bg_contact_selected = { 0.16, 0.18, 0.28, 0.80 },
  bg_input = { 0.17, 0.19, 0.26, 1.0 },
  text_primary = { 0.92, 0.92, 0.95, 1.0 },
  text_secondary = { 0.55, 0.55, 0.62, 1.0 },
  text_sent = { 0.95, 0.95, 0.98, 1.0 },
  text_received = { 0.88, 0.88, 0.92, 1.0 },
  text_system = { 0.65, 0.58, 0.40, 1.0 },
  text_timestamp = { 0.45, 0.45, 0.52, 1.0 },
  accent = { 0.20, 0.55, 0.95, 1.0 },
  online = { 0.30, 0.82, 0.40, 1.0 },
  offline = { 0.45, 0.45, 0.50, 1.0 },
  away = { 0.90, 0.72, 0.20, 1.0 },
  dnd = { 0.85, 0.25, 0.25, 1.0 },
  unread_badge = { 0.15, 0.38, 0.55, 0.80 },
  divider = { 0.15, 0.16, 0.22, 0.60 },
  scrollbar = { 0.35, 0.35, 0.42, 0.50 },
  scrollbar_hover = { 0.45, 0.45, 0.52, 0.70 },
  accent_bar = { 0.20, 0.55, 0.95, 1.0 },
  send_button = { 0.15, 0.38, 0.55, 1.0 },
  send_button_hover = { 0.20, 0.45, 0.65, 1.0 },
  send_button_disabled = { 0.25, 0.25, 0.30, 0.60 },
  icon_bg = { 0.18, 0.50, 0.95, 0.95 },
  badge_bg = { 0.90, 0.25, 0.25, 0.95 },
  option_button_bg = { 0.14, 0.15, 0.20, 0.80 },
  option_button_hover = { 0.18, 0.20, 0.28, 0.90 },
  option_button_text = { 0.82, 0.82, 0.88, 1.0 },
  option_button_text_hover = { 0.95, 0.95, 0.98, 1.0 },
  danger_button_bg = { 0.45, 0.12, 0.12, 0.80 },
  danger_button_hover = { 0.55, 0.16, 0.16, 0.90 },
  action_icon = { 0.55, 0.55, 0.62, 0.70 },
  action_icon_hover = { 0.92, 0.92, 0.95, 1.0 },
  action_icon_pinned = { 0.90, 0.72, 0.20, 1.0 },
  action_remove_hover = { 0.85, 0.25, 0.25, 1.0 },
}

ns.ThemeColors = Colors
return Colors
