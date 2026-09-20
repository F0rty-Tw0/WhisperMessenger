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

local textSecondaryRgb = rgb(0.72, 0.72, 0.72)
local jadeRgb = rgb(0.047, 0.824, 0.616)

local roles = {
  surface_primary = { 0.067, 0.067, 0.067, 0.94 },
  surface_secondary = { 0.09, 0.09, 0.09, 0.82 },
  surface_chrome = { 0.075, 0.075, 0.075, 0.92 },
  contact_hover = { 0.13, 0.14, 0.14, 0.92 },
  contact_selected = { 0.10, 0.20, 0.18, 0.95 },
  contact_selected_hover = { 0.13, 0.26, 0.23, 0.98 },
  contact_pinned = { 0.10, 0.10, 0.10, 0.78 },
  bubble_in = { 0.14, 0.14, 0.14, 0.95 },
  bubble_out = { 0.09, 0.22, 0.19, 0.90 },
  bubble_system = { 0.10, 0.10, 0.10, 0.78 },
  input_bg = { 0.10, 0.10, 0.10, 1.0 },
  text_primary = { 0.96, 0.96, 0.96, 1.0 },
  text_soft = { 0.84, 0.86, 0.86, 1.0 },
  text_secondary = withAlpha(textSecondaryRgb, 1.0),
  text_emphasis = { 0.99, 1.0, 0.99, 1.0 },
  text_system = { 0.78, 0.82, 0.80, 1.0 },
  text_timestamp = { 0.56, 0.60, 0.58, 1.0 },
  accent = withAlpha(jadeRgb, 1.0),
  accent_soft = { 0.04, 0.62, 0.47, 0.88 },
  toggle_on = withAlpha(jadeRgb, 1.0),
  button_fill = { 0.16, 0.16, 0.16, 1.0 },
  button_fill_hover = { 0.22, 0.22, 0.22, 1.0 },
  button_disabled = { 0.24, 0.24, 0.24, 0.65 },
  status_online = { 0.30, 0.82, 0.40, 1.0 },
  status_offline = { 0.45, 0.45, 0.45, 1.0 },
  status_away = { 0.90, 0.72, 0.20, 1.0 },
  status_dnd = { 0.85, 0.25, 0.25, 1.0 },
  scrollbar = { 0.30, 0.30, 0.30, 0.50 },
  scrollbar_hover = { 0.40, 0.40, 0.40, 0.70 },
  option_bg = { 0.09, 0.09, 0.09, 0.92 },
  toggle_off = { 0.20, 0.20, 0.20, 0.96 },
  toggle_border = { 0.40, 0.40, 0.40, 0.90 },
  composer_pane_border = { 0.30, 0.30, 0.30, 1.0 },
  danger_bg = { 0.45, 0.12, 0.12, 0.80 },
  danger_hover = { 0.55, 0.16, 0.16, 0.90 },
  action_icon = withAlpha(textSecondaryRgb, 0.70),
  toggle_icon_bg = { 0.10, 0.10, 0.10, 1.0 },
  toggle_icon_ring = withAlpha(jadeRgb, 0.55),
  toggle_icon_glyph = { 0.96, 0.96, 0.96, 1.0 },
}

local dividers = makeDividerRoles(rgb(0.20, 0.20, 0.20), 0.75, 0.90, jadeRgb, 0.60, 0.07, jadeRgb, 0.20)
for k, v in pairs(dividers) do
  roles[k] = v
end

local data = { key = "jade_dark", roles = roles }

ns.ThemePresetDataJadeDark = data
return data
