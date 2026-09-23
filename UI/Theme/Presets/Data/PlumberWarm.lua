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

local function makeDividerRoles(baseRgb, baseAlpha, strongAlpha, hoverRgb, hoverAlpha)
  return {
    divider = withAlpha(baseRgb, baseAlpha),
    divider_strong = withAlpha(baseRgb, strongAlpha),
    divider_hover = withAlpha(hoverRgb, hoverAlpha),
  }
end

local textSecondaryRgb = rgb(0.82, 0.72, 0.62)

local roles = {
  surface_primary = { 0.12, 0.10, 0.08, 0.97 },
  surface_secondary = { 0.18, 0.14, 0.10, 0.72 },
  surface_chrome = { 0.16, 0.12, 0.09, 0.76 },
  contact_hover = { 1.0, 1.0, 1.0, 0.05 },
  contact_selected = { 0.88, 0.56, 0.22, 0.16 },
  contact_selected_hover = { 0.88, 0.56, 0.22, 0.22 },
  -- Pinned reads through ordering and the hover pin, not a colour.
  contact_pinned = { 0.88, 0.56, 0.22, 0.05 },
  bubble_in = { 0.24, 0.18, 0.14, 0.90 },
  bubble_out = { 0.55, 0.30, 0.18, 0.84 },
  bubble_system = { 0.24, 0.18, 0.12, 0.72 },
  input_bg = { 0.31, 0.22, 0.16, 0.98 },
  text_primary = { 0.95, 0.90, 0.84, 1.0 },
  text_soft = { 0.95, 0.90, 0.84, 1.0 },
  text_secondary = withAlpha(textSecondaryRgb, 1.0),
  text_emphasis = { 1.0, 0.97, 0.92, 1.0 },
  text_system = { 0.90, 0.72, 0.42, 1.0 },
  text_timestamp = { 0.72, 0.60, 0.48, 1.0 },
  accent = { 0.88, 0.56, 0.22, 1.0 },
  toggle_on = { 0.88, 0.56, 0.22, 1.0 },
  button_fill_hover = { 0.86, 0.52, 0.28, 1.0 },
  status_online = { 0.30, 0.82, 0.40, 1.0 },
  status_offline = { 0.45, 0.45, 0.50, 1.0 },
  status_away = { 0.90, 0.72, 0.20, 1.0 },
  status_dnd = { 0.85, 0.25, 0.25, 1.0 },
  scrollbar = { 1.0, 1.0, 1.0, 0.14 },
  scrollbar_hover = { 1.0, 1.0, 1.0, 0.32 },
  option_bg = { 0.25, 0.18, 0.13, 0.88 },
  toggle_off = { 0.30, 0.24, 0.20, 0.95 },
  composer_pane_border = { 1.0, 1.0, 1.0, 0.08 },
  window_border = { 1.0, 1.0, 1.0, 0.10 },
  danger_bg = { 0.45, 0.12, 0.12, 0.80 },
  danger_hover = { 0.55, 0.16, 0.16, 0.90 },
  action_icon = withAlpha(textSecondaryRgb, 0.70),
  toggle_icon_bg = { 0.74, 0.40, 0.20, 1.0 },
  toggle_icon_ring = { 0.88, 0.56, 0.22, 0.60 },
  toggle_icon_glyph = { 1.0, 0.97, 0.92, 1.0 },
}

-- White-plus-alpha hairlines read as neutral on any surface tone.
local dividers = makeDividerRoles(rgb(1.0, 1.0, 1.0), 0.08, 0.10, rgb(1.0, 1.0, 1.0), 0.16)
for k, v in pairs(dividers) do
  roles[k] = v
end

local data = { key = "plumber_warm", roles = roles }

ns.ThemePresetDataPlumberWarm = data
return data
