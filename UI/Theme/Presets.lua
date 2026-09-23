local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Presets = {}

Presets.WOW_DEFAULT = "wow_default"
Presets.ELVUI_DARK = "elvui_dark"
Presets.PLUMBER_WARM = "plumber_warm"
Presets.JADE_DARK = "jade_dark"
Presets.WOW_NATIVE = "wow_native"

local Builder = ns.ThemePresetsBuilder or require("WhisperMessenger.UI.Theme.Presets.Builder")

local dataWowDefault = ns.ThemePresetDataWowDefault or require("WhisperMessenger.UI.Theme.Presets.Data.WowDefault")
local dataElvuiDark = ns.ThemePresetDataElvuiDark or require("WhisperMessenger.UI.Theme.Presets.Data.ElvuiDark")
local dataPlumberWarm = ns.ThemePresetDataPlumberWarm or require("WhisperMessenger.UI.Theme.Presets.Data.PlumberWarm")
local dataJadeDark = ns.ThemePresetDataJadeDark or require("WhisperMessenger.UI.Theme.Presets.Data.JadeDark")
local dataWowNative = ns.ThemePresetDataWowNative or require("WhisperMessenger.UI.Theme.Presets.Data.WowNative")

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
  -- Every unread badge (rows, tabs, widget, minimap): accent circle with
  -- knockout (surface-coloured) text, readable on every preset's accent.
  unread_badge = "accent",
  unread_badge_text = "surface_primary",
  divider = "divider",
  window_border = "window_border",
  contacts_divider = "divider",
  contacts_border_right = "divider_strong",
  composer_pane_border = "composer_pane_border",
  contacts_divider_hover = "divider_hover",
  scrollbar = "scrollbar",
  scrollbar_hover = "scrollbar_hover",
  send_button_hover = "button_fill_hover",
  ghost_button_fill_hover = "contact_hover",
  ghost_button_border = "divider_strong",
  ghost_button_text = "text_soft",
  toggle_icon_bg = "toggle_icon_bg",
  toggle_icon_ring = "toggle_icon_ring",
  toggle_icon_glyph = "toggle_icon_glyph",
  option_button_bg = "option_bg",
  option_button_hover = "contact_hover",
  option_button_active = "contact_selected",
  option_button_active_hover = "contact_selected_hover",
  option_button_text = "text_soft",
  option_button_text_hover = "text_emphasis",
  option_button_text_active = "text_emphasis",
  option_toggle_on = "toggle_on",
  option_toggle_off = "toggle_off",
  danger_button_bg = "danger_bg",
  danger_button_hover = "danger_hover",
  -- Modern settings controls: switch knob / slider thumb, slider track and
  -- fill, and the red text of the danger ghost button.
  control_knob = "text_emphasis",
  slider_track = "scrollbar",
  slider_fill = "accent",
  danger_text = "status_dnd",
  action_icon = "action_icon",
  action_icon_hover = "text_primary",
  action_remove_hover = "status_dnd",
}

local presetOrder = {
  Presets.WOW_DEFAULT,
  Presets.ELVUI_DARK,
  Presets.PLUMBER_WARM,
  Presets.JADE_DARK,
  Presets.WOW_NATIVE,
}

local presetDataFiles = {
  [Presets.WOW_DEFAULT] = dataWowDefault,
  [Presets.ELVUI_DARK] = dataElvuiDark,
  [Presets.PLUMBER_WARM] = dataPlumberWarm,
  [Presets.JADE_DARK] = dataJadeDark,
  [Presets.WOW_NATIVE] = dataWowNative,
}

local presetData = {}
for _, key in ipairs(presetOrder) do
  local dataFile = presetDataFiles[key]
  if type(dataFile) ~= "table" or type(dataFile.roles) ~= "table" then
    error(("missing preset role set for '%s'"):format(tostring(key)))
  end
  presetData[key] = Builder.BuildPreset(tokenRoles, dataFile.roles)
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

ns.ThemePresets = Presets
return Presets
