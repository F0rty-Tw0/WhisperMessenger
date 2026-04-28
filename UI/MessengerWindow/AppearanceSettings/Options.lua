local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")

local Options = {}

Options.FONT_OPTIONS = {
  { key = "default", label = "Default", tooltip = "Inherits your game font. Supports all languages." },
  { key = "system", label = "System", tooltip = "Arial Narrow. Clean sans-serif look." },
  { key = "morpheus", label = "Morpheus", tooltip = "Fantasy decorative font. Great for immersion." },
}

Options.OUTLINE_OPTIONS = {
  { key = "NONE", label = "None", tooltip = "No outline on text." },
  { key = "OUTLINE", label = "Outline", tooltip = "Thin outline for readability." },
  { key = "THICKOUTLINE", label = "Thick", tooltip = "Thick outline for maximum contrast." },
}

-- Theme preset display labels are branding (Midnight, Shadowlands, Draenor,
-- Azeroth) — they identify the preset to the player, not the underlying
-- expansion's color palette.
local PRESET_LABELS = {
  wow_default = { label = "Midnight", tooltip = "Default colors and contrasts." },
  elvui_dark = { label = "Shadowlands", tooltip = "Dark UI style inspired by ElvUI." },
  plumber_warm = { label = "Draenor", tooltip = "Warm tones with softer contrast." },
  wow_native = { label = "Azeroth", tooltip = "Native WoW colors with gold accents." },
}

local BUBBLE_COLOR_LABELS = {
  default = { label = "Default", tooltip = "Uses your theme's bubble colors." },
  shadow = { label = "Shadow", tooltip = "Muted dark tones." },
  ember = { label = "Ember", tooltip = "Warm earthy tones." },
  arcane = { label = "Arcane", tooltip = "Purple arcane-infused tones." },
  frost = { label = "Frost", tooltip = "Cool steel-blue tones." },
  fel = { label = "Fel", tooltip = "Eerie fel-green tones." },
}

function Options.BuildFontColorOptions()
  local presets = Fonts.ListFontColorPresets and Fonts.ListFontColorPresets() or {}
  local result = {}
  for _, p in ipairs(presets) do
    result[#result + 1] = {
      key = p.key,
      label = p.label,
      tooltip = p.rgba and (p.label .. " text color") or "Use theme colors",
    }
  end
  return result
end

function Options.BuildThemePresetOptions()
  local keys = Theme.ListPresets and Theme.ListPresets() or { "wow_default", "elvui_dark", "plumber_warm" }
  return SettingsControls.ProjectLabeledOptions(keys, PRESET_LABELS, function(key)
    return { label = key, tooltip = "Theme preset" }
  end)
end

function Options.BuildBubbleColorOptions()
  local keys = Theme.ListBubblePresets and Theme.ListBubblePresets() or { "default" }
  return SettingsControls.ProjectLabeledOptions(keys, BUBBLE_COLOR_LABELS, function(key)
    return { label = key, tooltip = "Bubble color preset" }
  end)
end

ns.AppearanceSettingsOptions = Options
return Options
