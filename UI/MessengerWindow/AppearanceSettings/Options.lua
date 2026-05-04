local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local Options = {}

local FONT_OPTION_SPECS = {
  { key = "default", label = "Default", tooltip = "Inherits your game font. Supports all languages." },
  { key = "system", label = "System", tooltip = "Arial Narrow. Clean sans-serif look." },
  { key = "morpheus", label = "Morpheus", tooltip = "Fantasy decorative font. Great for immersion." },
}

local OUTLINE_OPTION_SPECS = {
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

local function localizeOptionSpecs(specs)
  local localized = {}
  for _, spec in ipairs(specs) do
    localized[#localized + 1] = {
      key = spec.key,
      label = Localization.Text(spec.label),
      tooltip = Localization.Text(spec.tooltip),
    }
  end
  return localized
end

function Options.BuildFontOptions()
  return localizeOptionSpecs(FONT_OPTION_SPECS)
end

function Options.BuildOutlineOptions()
  return localizeOptionSpecs(OUTLINE_OPTION_SPECS)
end

Options.FONT_OPTIONS = Options.BuildFontOptions()
Options.OUTLINE_OPTIONS = Options.BuildOutlineOptions()

function Options.BuildFontColorOptions()
  local presets = Fonts.ListFontColorPresets and Fonts.ListFontColorPresets() or {}
  local result = {}
  for _, p in ipairs(presets) do
    result[#result + 1] = {
      key = p.key,
      label = Localization.Text(p.label),
      tooltip = p.rgba and (Localization.Text(p.label) .. Localization.Text(" text color")) or Localization.Text("Use theme colors"),
    }
  end
  return result
end

function Options.BuildThemePresetOptions()
  local keys = Theme.ListPresets and Theme.ListPresets() or { "wow_default", "elvui_dark", "plumber_warm" }
  return SettingsControls.ProjectLabeledOptions(keys, PRESET_LABELS, function(key)
    return { label = key, tooltip = "Theme preset" }
  end, Localization.Text)
end

function Options.BuildBubbleColorOptions()
  local keys = Theme.ListBubblePresets and Theme.ListBubblePresets() or { "default" }
  return SettingsControls.ProjectLabeledOptions(keys, BUBBLE_COLOR_LABELS, function(key)
    return { label = key, tooltip = "Bubble color preset" }
  end, Localization.Text)
end

ns.AppearanceSettingsOptions = Options
return Options
