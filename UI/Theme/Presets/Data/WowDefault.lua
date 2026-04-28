local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local function rgb(r, g, b)
  return { r, g, b }
end

local function withAlpha(baseRgb, alpha)
  return { baseRgb[1], baseRgb[2], baseRgb[3], alpha }
end

local function makeDividerRoles(baseRgb, baseAlpha, strongAlpha, hoverRgb, hoverAlpha, fillAlpha, outlineRgb, outlineAlpha)
  return {
    divider = withAlpha(baseRgb, baseAlpha),
    divider_strong = withAlpha(baseRgb, strongAlpha),
    divider_hover = withAlpha(hoverRgb, hoverAlpha),
    divider_fill = withAlpha(hoverRgb, fillAlpha),
    divider_outline = withAlpha(outlineRgb or hoverRgb, outlineAlpha),
  }
end

local textSecondaryRgb = rgb(0.55, 0.55, 0.62)

local roles = {
  surface_primary = { 0.07, 0.07, 0.10, 0.97 },
  surface_secondary = { 0.10, 0.10, 0.14, 0.60 },
  surface_chrome = { 0.09, 0.09, 0.13, 0.60 },
  contact_hover = { 0.18, 0.20, 0.30, 0.82 },
  contact_selected = { 0.24, 0.32, 0.54, 0.96 },
  contact_selected_hover = { 0.28, 0.38, 0.62, 0.98 },
  contact_pinned = { 0.14, 0.13, 0.10, 0.72 },
  bubble_in = { 0.20, 0.24, 0.34, 0.95 },
  bubble_out = { 0.15, 0.38, 0.55, 0.80 },
  bubble_system = { 0.14, 0.12, 0.10, 0.65 },
  input_bg = { 0.17, 0.19, 0.26, 1.0 },
  text_primary = { 0.92, 0.92, 0.95, 1.0 },
  text_soft = { 0.84, 0.86, 0.92, 1.0 },
  text_secondary = withAlpha(textSecondaryRgb, 1.0),
  text_emphasis = { 0.98, 0.99, 1.0, 1.0 },
  text_system = { 0.65, 0.58, 0.40, 1.0 },
  text_timestamp = { 0.45, 0.45, 0.52, 1.0 },
  accent = { 0.12, 0.72, 0.96, 1.0 },
  accent_soft = { 0.15, 0.38, 0.55, 0.80 },
  toggle_on = { 0.12, 0.72, 0.96, 1.0 },
  button_fill = { 0.15, 0.38, 0.55, 1.0 },
  button_fill_hover = { 0.20, 0.45, 0.65, 1.0 },
  button_disabled = { 0.25, 0.25, 0.30, 0.60 },
  status_online = { 0.30, 0.82, 0.40, 1.0 },
  status_offline = { 0.45, 0.45, 0.50, 1.0 },
  status_away = { 0.90, 0.72, 0.20, 1.0 },
  status_dnd = { 0.85, 0.25, 0.25, 1.0 },
  scrollbar = { 0.35, 0.35, 0.42, 0.50 },
  scrollbar_hover = { 0.45, 0.45, 0.52, 0.70 },
  option_bg = { 0.12, 0.13, 0.18, 0.90 },
  toggle_off = { 0.32, 0.33, 0.40, 0.95 },
  toggle_border = { 0.56, 0.58, 0.66, 0.90 },
  composer_pane_border = { 0.15, 0.16, 0.22, 1.0 },
  toggle_icon_bg = { 0.12, 0.72, 0.96, 1.0 },
  toggle_icon_ring = { 0.12, 0.72, 0.96, 0.55 },
  toggle_icon_glyph = { 0.98, 0.99, 1.00, 1.0 },
  danger_bg = { 0.45, 0.12, 0.12, 0.80 },
  danger_hover = { 0.55, 0.16, 0.16, 0.90 },
  action_icon = withAlpha(textSecondaryRgb, 0.70),
}

local dividers = makeDividerRoles(rgb(0.15, 0.16, 0.22), 0.60, 0.90, rgb(0.18, 0.19, 0.25), 0.72, 0.08, rgb(0.20, 0.22, 0.30), 0.20)
for k, v in pairs(dividers) do
  roles[k] = v
end

local data = { key = "wow_default", roles = roles }

ns.ThemePresetDataWowDefault = data
return data
