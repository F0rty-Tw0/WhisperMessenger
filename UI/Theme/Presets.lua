local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Presets = {}

Presets.WOW_DEFAULT = "wow_default"
Presets.ELVUI_DARK = "elvui_dark"
Presets.PLUMBER_WARM = "plumber_warm"
Presets.WOW_NATIVE = "wow_native"

local Builder = ns.ThemePresetsBuilder or require("WhisperMessenger.UI.Theme.Presets.Builder")

local function rgb(r, g, b)
  return { r, g, b }
end

local function withAlpha(baseRgb, alpha)
  return { baseRgb[1], baseRgb[2], baseRgb[3], alpha }
end

local function mergeRoleSets(...)
  local merged = {}

  for i = 1, select("#", ...) do
    local roleSet = select(i, ...)
    if type(roleSet) == "table" then
      for key, color in pairs(roleSet) do
        merged[key] = color
      end
    end
  end

  return merged
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

local tokenRoles = {
  bg_primary = "surface_primary",
  bg_secondary = "surface_secondary",
  bg_bubble_in = "bubble_in",
  bg_bubble_out = "bubble_out",
  bg_bubble_system = "bubble_system",
  bg_composer = "surface_chrome",
  bg_header = "surface_chrome",
  bg_contact_hover = "contact_hover",
  bg_contact_pinned = "contact_pinned",
  bg_contact_selected = "contact_selected",
  contact_selected_border_right = "accent",
  bg_input = "input_bg",
  bg_search_input = "input_bg",
  bg_message_input = "input_bg",
  text_primary = "text_primary",
  text_title = "text_emphasis",
  text_secondary = "text_secondary",
  text_sent = "text_emphasis",
  text_received = "text_primary",
  text_system = "text_system",
  text_timestamp = "text_timestamp",
  accent = "accent",
  accent_primary = "accent",
  accent_bar = "accent",
  online = "status_online",
  offline = "status_offline",
  away = "status_away",
  dnd = "status_dnd",
  unread_badge = "accent_soft",
  divider = "divider",
  contacts_divider = "divider",
  contacts_border_right = "divider_strong",
  composer_pane_border = "composer_pane_border",
  contacts_divider_hover = "divider_hover",
  contacts_resize_hover_fill = "divider_fill",
  contacts_resize_outline = "divider_outline",
  scrollbar = "scrollbar",
  scrollbar_hover = "scrollbar_hover",
  send_button = "button_fill",
  send_button_hover = "button_fill_hover",
  send_button_disabled = "button_disabled",
  send_button_text = "text_emphasis",
  send_button_text_disabled = "text_soft",
  icon_bg = "accent",
  badge_bg = "status_dnd",
  option_button_bg = "option_bg",
  option_button_hover = "contact_hover",
  option_button_active = "contact_selected",
  option_button_active_hover = "contact_selected_hover",
  option_button_text = "text_soft",
  option_button_text_hover = "text_emphasis",
  option_button_text_active = "text_emphasis",
  option_toggle_on = "toggle_on",
  option_toggle_off = "toggle_off",
  option_toggle_border = "toggle_border",
  danger_button_bg = "danger_bg",
  danger_button_hover = "danger_hover",
  action_icon = "action_icon",
  action_icon_hover = "text_primary",
  action_icon_pinned = "status_away",
  action_remove_hover = "status_dnd",
}

local wowTextSecondaryRgb = rgb(0.55, 0.55, 0.62)
local elvuiTextSecondaryRgb = rgb(0.72, 0.72, 0.74)
local plumberTextSecondaryRgb = rgb(0.82, 0.72, 0.62)
local wowNativeTextSecondaryRgb = rgb(1.00, 0.82, 0.00)

local presetRoles = {
  [Presets.WOW_DEFAULT] = mergeRoleSets(
    {
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
      text_secondary = withAlpha(wowTextSecondaryRgb, 1.0),
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
      danger_bg = { 0.45, 0.12, 0.12, 0.80 },
      danger_hover = { 0.55, 0.16, 0.16, 0.90 },
      action_icon = withAlpha(wowTextSecondaryRgb, 0.70),
    },
    makeDividerRoles(rgb(0.15, 0.16, 0.22), 0.60, 0.90, rgb(0.18, 0.19, 0.25), 0.72, 0.08, rgb(0.20, 0.22, 0.30), 0.20)
  ),
  [Presets.ELVUI_DARK] = mergeRoleSets(
    {
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
      text_secondary = withAlpha(elvuiTextSecondaryRgb, 1.0),
      text_emphasis = { 0.99, 0.99, 1.0, 1.0 },
      text_system = { 0.78, 0.80, 0.86, 1.0 },
      text_timestamp = { 0.56, 0.58, 0.64, 1.0 },
      accent = { 0.34, 0.51, 0.90, 1.0 },
      accent_soft = { 0.18, 0.50, 0.76, 0.88 },
      toggle_on = { 0.34, 0.51, 0.90, 1.0 },
      button_fill = { 0.20, 0.56, 0.84, 1.0 },
      button_fill_hover = { 0.26, 0.64, 0.92, 1.0 },
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
      action_icon = withAlpha(elvuiTextSecondaryRgb, 0.70),
    },
    makeDividerRoles(rgb(0.15, 0.16, 0.20), 0.75, 0.90, rgb(0.17, 0.18, 0.23), 0.72, 0.07, rgb(0.17, 0.18, 0.23), 0.20)
  ),
  [Presets.PLUMBER_WARM] = mergeRoleSets(
    {
      surface_primary = { 0.12, 0.10, 0.08, 0.97 },
      surface_secondary = { 0.18, 0.14, 0.10, 0.72 },
      surface_chrome = { 0.16, 0.12, 0.09, 0.76 },
      contact_hover = { 0.34, 0.24, 0.17, 0.84 },
      contact_selected = { 0.47, 0.32, 0.20, 0.94 },
      contact_selected_hover = { 0.64, 0.44, 0.28, 0.98 },
      contact_pinned = { 0.34, 0.24, 0.16, 0.80 },
      bubble_in = { 0.24, 0.18, 0.14, 0.90 },
      bubble_out = { 0.55, 0.30, 0.18, 0.84 },
      bubble_system = { 0.24, 0.18, 0.12, 0.72 },
      input_bg = { 0.31, 0.22, 0.16, 0.98 },
      text_primary = { 0.95, 0.90, 0.84, 1.0 },
      text_soft = { 0.95, 0.90, 0.84, 1.0 },
      text_secondary = withAlpha(plumberTextSecondaryRgb, 1.0),
      text_emphasis = { 1.0, 0.97, 0.92, 1.0 },
      text_system = { 0.90, 0.72, 0.42, 1.0 },
      text_timestamp = { 0.72, 0.60, 0.48, 1.0 },
      accent = { 0.88, 0.56, 0.22, 1.0 },
      accent_soft = { 0.55, 0.30, 0.18, 0.84 },
      toggle_on = { 0.88, 0.56, 0.22, 1.0 },
      button_fill = { 0.74, 0.40, 0.20, 1.0 },
      button_fill_hover = { 0.86, 0.52, 0.28, 1.0 },
      button_disabled = { 0.36, 0.24, 0.16, 0.72 },
      status_online = { 0.30, 0.82, 0.40, 1.0 },
      status_offline = { 0.45, 0.45, 0.50, 1.0 },
      status_away = { 0.90, 0.72, 0.20, 1.0 },
      status_dnd = { 0.85, 0.25, 0.25, 1.0 },
      scrollbar = { 0.58, 0.44, 0.32, 0.52 },
      scrollbar_hover = { 0.72, 0.54, 0.40, 0.74 },
      option_bg = { 0.25, 0.18, 0.13, 0.88 },
      toggle_off = { 0.30, 0.24, 0.20, 0.95 },
      toggle_border = { 0.42, 0.32, 0.24, 0.75 },
      composer_pane_border = { 0.42, 0.29, 0.20, 1.0 },
      danger_bg = { 0.45, 0.12, 0.12, 0.80 },
      danger_hover = { 0.55, 0.16, 0.16, 0.90 },
      action_icon = withAlpha(plumberTextSecondaryRgb, 0.70),
    },
    makeDividerRoles(rgb(0.42, 0.29, 0.20), 0.78, 0.90, rgb(0.48, 0.34, 0.24), 0.80, 0.08, rgb(0.48, 0.34, 0.24), 0.24)
  ),
  [Presets.WOW_NATIVE] = mergeRoleSets(
    {
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
      text_secondary = withAlpha(wowNativeTextSecondaryRgb, 1.0),
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
      action_icon = withAlpha(wowNativeTextSecondaryRgb, 0.70),
    },
    makeDividerRoles(rgb(0.40, 0.32, 0.10), 0.60, 0.95, rgb(0.55, 0.44, 0.14), 0.72, 0.10, rgb(0.60, 0.48, 0.16), 0.30)
  ),
}

local presetOrder = {
  Presets.WOW_DEFAULT,
  Presets.ELVUI_DARK,
  Presets.PLUMBER_WARM,
  Presets.WOW_NATIVE,
}

local presetData = {}
for _, key in ipairs(presetOrder) do
  local roles = presetRoles[key]
  if type(roles) ~= "table" then
    error(("missing preset role set for '%s'"):format(tostring(key)))
  end
  presetData[key] = Builder.BuildPreset(tokenRoles, roles)
end

function Presets.ListKeys()
  local keys = {}
  for i, key in ipairs(presetOrder) do
    keys[i] = key
  end

  return keys
end

function Presets.Get(key)
  local preset = presetData[key]
  if type(preset) ~= "table" then
    return nil
  end

  return Builder.ClonePalette(preset)
end

Presets.DATA = presetData

ns.ThemePresets = Presets
return Presets
