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

local dataWowDefault = ns.ThemePresetDataWowDefault or require("WhisperMessenger.UI.Theme.Presets.Data.WowDefault")
local dataElvuiDark = ns.ThemePresetDataElvuiDark or require("WhisperMessenger.UI.Theme.Presets.Data.ElvuiDark")
local dataPlumberWarm = ns.ThemePresetDataPlumberWarm or require("WhisperMessenger.UI.Theme.Presets.Data.PlumberWarm")
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
  toggle_icon_bg = "toggle_icon_bg",
  toggle_icon_ring = "toggle_icon_ring",
  toggle_icon_glyph = "toggle_icon_glyph",
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

local presetOrder = {
  Presets.WOW_DEFAULT,
  Presets.ELVUI_DARK,
  Presets.PLUMBER_WARM,
  Presets.WOW_NATIVE,
}

local presetDataFiles = {
  [Presets.WOW_DEFAULT] = dataWowDefault,
  [Presets.ELVUI_DARK] = dataElvuiDark,
  [Presets.PLUMBER_WARM] = dataPlumberWarm,
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

Presets.DATA = presetData

ns.ThemePresets = Presets
return Presets
