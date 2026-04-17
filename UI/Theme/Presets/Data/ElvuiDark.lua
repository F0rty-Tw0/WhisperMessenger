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

local function makeDividerRoles(
  baseRgb,
  baseAlpha,
  strongAlpha,
  hoverRgb,
  hoverAlpha,
  fillAlpha,
  outlineRgb,
  outlineAlpha
)
  return {
    divider = withAlpha(baseRgb, baseAlpha),
    divider_strong = withAlpha(baseRgb, strongAlpha),
    divider_hover = withAlpha(hoverRgb, hoverAlpha),
    divider_fill = withAlpha(hoverRgb, fillAlpha),
    divider_outline = withAlpha(outlineRgb or hoverRgb, outlineAlpha),
  }
end

local textSecondaryRgb = rgb(0.72, 0.72, 0.74)

local roles = {
  surface_primary = { 0.03, 0.03, 0.03, 0.98 },
  surface_secondary = { 0.06, 0.06, 0.07, 0.80 },
  surface_chrome = { 0.05, 0.05, 0.06, 0.90 },
  contact_hover = { 0.14, 0.16, 0.20, 0.92 },
  contact_selected = { 0.15, 0.17, 0.22, 0.95 },
  contact_selected_hover = { 0.22, 0.25, 0.32, 0.98 },
  contact_pinned = { 0.10, 0.10, 0.12, 0.78 },
  bubble_in = { 0.16, 0.17, 0.20, 0.95 },
  bubble_out = { 0.13, 0.16, 0.20, 0.88 },
  bubble_system = { 0.10, 0.10, 0.12, 0.78 },
  input_bg = { 0.09, 0.10, 0.12, 1.0 },
  text_primary = { 0.96, 0.96, 0.96, 1.0 },
  text_soft = { 0.84, 0.86, 0.90, 1.0 },
  text_secondary = withAlpha(textSecondaryRgb, 1.0),
  text_emphasis = { 0.99, 0.99, 1.0, 1.0 },
  text_system = { 0.78, 0.80, 0.86, 1.0 },
  text_timestamp = { 0.56, 0.58, 0.64, 1.0 },
  accent = { 0.34, 0.51, 0.90, 1.0 },
  accent_soft = { 0.18, 0.50, 0.76, 0.88 },
  toggle_on = { 0.34, 0.51, 0.90, 1.0 },
  button_fill = { 0.20, 0.22, 0.26, 1.0 },
  button_fill_hover = { 0.30, 0.32, 0.38, 1.0 },
  button_disabled = { 0.30, 0.32, 0.36, 0.65 },
  status_online = { 0.30, 0.82, 0.40, 1.0 },
  status_offline = { 0.45, 0.45, 0.50, 1.0 },
  status_away = { 0.90, 0.72, 0.20, 1.0 },
  status_dnd = { 0.85, 0.25, 0.25, 1.0 },
  scrollbar = { 0.35, 0.35, 0.42, 0.50 },
  scrollbar_hover = { 0.45, 0.45, 0.52, 0.70 },
  option_bg = { 0.09, 0.09, 0.10, 0.92 },
  toggle_off = { 0.22, 0.23, 0.27, 0.96 },
  toggle_border = { 0.50, 0.52, 0.58, 0.90 },
  composer_pane_border = { 0.48, 0.50, 0.58, 1.0 },
  danger_bg = { 0.45, 0.12, 0.12, 0.80 },
  danger_hover = { 0.55, 0.16, 0.16, 0.90 },
  action_icon = withAlpha(textSecondaryRgb, 0.70),
}

local dividers =
  makeDividerRoles(rgb(0.15, 0.16, 0.20), 0.75, 0.90, rgb(0.17, 0.18, 0.23), 0.72, 0.07, rgb(0.17, 0.18, 0.23), 0.20)
for k, v in pairs(dividers) do
  roles[k] = v
end

local data = { key = "elvui_dark", roles = roles }

ns.ThemePresetDataElvuiDark = data
return data
