local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ThemePresets = ns.ThemePresets
if type(ThemePresets) ~= "table" and type(require) == "function" then
  ThemePresets = require("WhisperMessenger.UI.Theme.Presets")
end
if type(ThemePresets) ~= "table" or type(ThemePresets.Get) ~= "function" then
  error("ThemePresets module not available")
end

local Colors = ThemePresets.Get(ThemePresets.WOW_DEFAULT) or {}

ns.ThemeColors = Colors
return Colors