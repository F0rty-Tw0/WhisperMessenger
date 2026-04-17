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

local textSecondaryRgb = rgb(1.00, 0.82, 0.00)

local roles = {
  -- Native WoW frames render as a single uniform near-black surface.
  -- Equal RGB + alpha 1.0 across primary/secondary/chrome kills the
  -- two-tone look and the right-edge bleed-through reported in-game.
  surface_primary = { 0.04, 0.04, 0.06, 1.0 },
  surface_secondary = { 0.04, 0.04, 0.06, 1.0 },
  surface_chrome = { 0.04, 0.04, 0.06, 1.0 },
  contact_hover = { 0.20, 0.16, 0.06, 0.85 },
  contact_selected = { 0.36, 0.28, 0.06, 0.95 },
  contact_selected_hover = { 0.44, 0.34, 0.08, 0.98 },
  contact_pinned = { 0.16, 0.13, 0.04, 0.78 },
  -- Slate gray with cool tint: the original near-black {0.08, 0.08,
  -- 0.10} was almost indistinguishable from the now-opaque near-black
  -- surface. This contrasts clearly while staying in the dark/native
  -- WoW palette family.
  bubble_in = { 0.18, 0.20, 0.26, 1.0 },
  bubble_out = { 0.30, 0.13, 0.36, 0.82 },
  bubble_system = { 0.10, 0.08, 0.04, 0.78 },
  input_bg = { 0.06, 0.06, 0.08, 1.0 },
  text_primary = { 1.00, 1.00, 1.00, 1.0 },
  text_soft = { 0.95, 0.95, 0.95, 1.0 },
  text_secondary = withAlpha(textSecondaryRgb, 1.0),
  text_emphasis = { 1.00, 0.82, 0.00, 1.0 },
  text_system = { 1.00, 1.00, 0.00, 1.0 },
  text_timestamp = { 0.50, 0.50, 0.50, 1.0 },
  accent = { 1.00, 0.82, 0.00, 1.0 },
  accent_soft = { 0.78, 0.36, 0.96, 0.80 },
  toggle_on = { 1.00, 0.82, 0.00, 1.0 },
  button_fill = { 0.32, 0.24, 0.06, 1.0 },
  button_fill_hover = { 0.42, 0.32, 0.08, 1.0 },
  button_disabled = { 0.18, 0.16, 0.10, 0.65 },
  status_online = { 0.10, 1.00, 0.10, 1.0 },
  status_offline = { 0.50, 0.50, 0.50, 1.0 },
  status_away = { 1.00, 0.50, 0.25, 1.0 },
  status_dnd = { 1.00, 0.10, 0.10, 1.0 },
  scrollbar = { 0.40, 0.32, 0.10, 0.55 },
  scrollbar_hover = { 0.55, 0.44, 0.14, 0.75 },
  option_bg = { 0.08, 0.08, 0.10, 0.92 },
  toggle_off = { 0.25, 0.25, 0.28, 0.95 },
  toggle_border = { 0.40, 0.32, 0.10, 0.70 },
  composer_pane_border = { 0.62, 0.50, 0.16, 1.0 },
  danger_bg = { 0.45, 0.12, 0.12, 0.80 },
  danger_hover = { 0.55, 0.16, 0.16, 0.90 },
  action_icon = withAlpha(textSecondaryRgb, 0.70),
}

local dividers =
  makeDividerRoles(rgb(0.40, 0.32, 0.10), 0.60, 0.95, rgb(0.55, 0.44, 0.14), 0.72, 0.10, rgb(0.60, 0.48, 0.16), 0.30)
for k, v in pairs(dividers) do
  roles[k] = v
end

local data = { key = "wow_native", roles = roles }

ns.ThemePresetDataWowNative = data
return data
