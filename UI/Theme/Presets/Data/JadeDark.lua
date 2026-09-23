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

local textSecondaryRgb = rgb(1.0, 1.0, 1.0)
local jadeRgb = rgb(0.047, 0.824, 0.616)

local roles = {
  surface_primary = { 0.067, 0.067, 0.067, 0.94 },
  surface_secondary = { 0.09, 0.09, 0.09, 0.82 },
  surface_chrome = { 0.075, 0.075, 0.075, 0.92 },
  contact_hover = { 1.0, 1.0, 1.0, 0.05 },
  contact_selected = withAlpha(jadeRgb, 0.14),
  contact_selected_hover = withAlpha(jadeRgb, 0.20),
  -- Pinned reads through ordering and the hover pin, not a colour.
  contact_pinned = withAlpha(jadeRgb, 0.05),
  bubble_in = { 0.14, 0.14, 0.14, 0.95 },
  bubble_out = { 0.09, 0.22, 0.19, 0.90 },
  bubble_system = { 0.10, 0.10, 0.10, 0.78 },
  input_bg = { 0.10, 0.10, 0.10, 1.0 },
  text_primary = { 0.96, 0.96, 0.96, 1.0 },
  text_soft = { 0.84, 0.86, 0.86, 1.0 },
  text_secondary = withAlpha(textSecondaryRgb, 0.55),
  text_emphasis = { 0.99, 1.0, 0.99, 1.0 },
  text_system = { 0.78, 0.82, 0.80, 1.0 },
  text_timestamp = { 1.0, 1.0, 1.0, 0.40 },
  accent = withAlpha(jadeRgb, 1.0),
  toggle_on = withAlpha(jadeRgb, 1.0),
  button_fill_hover = withAlpha(jadeRgb, 1.0),
  status_online = { 0.30, 0.82, 0.40, 1.0 },
  status_offline = { 0.45, 0.45, 0.45, 1.0 },
  status_away = { 0.90, 0.72, 0.20, 1.0 },
  status_dnd = { 0.85, 0.25, 0.25, 1.0 },
  scrollbar = { 1.0, 1.0, 1.0, 0.14 },
  scrollbar_hover = { 1.0, 1.0, 1.0, 0.32 },
  option_bg = { 0.09, 0.09, 0.09, 0.92 },
  toggle_off = { 0.20, 0.20, 0.20, 0.96 },
  composer_pane_border = { 1.0, 1.0, 1.0, 0.08 },
  window_border = { 1.0, 1.0, 1.0, 0.10 },
  danger_bg = { 0.45, 0.12, 0.12, 0.80 },
  danger_hover = { 0.55, 0.16, 0.16, 0.90 },
  action_icon = withAlpha(textSecondaryRgb, 0.45),
  toggle_icon_bg = { 0.10, 0.10, 0.10, 1.0 },
  toggle_icon_ring = withAlpha(jadeRgb, 0.55),
  toggle_icon_glyph = { 0.96, 0.96, 0.96, 1.0 },
}

-- White-plus-alpha hairlines read as neutral on any surface tone.
local dividers = makeDividerRoles(rgb(1.0, 1.0, 1.0), 0.08, 0.10, rgb(1.0, 1.0, 1.0), 0.16)
for k, v in pairs(dividers) do
  roles[k] = v
end

local data = { key = "jade_dark", roles = roles }

ns.ThemePresetDataJadeDark = data
return data
