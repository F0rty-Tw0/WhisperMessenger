local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Colors = ns.ThemeColors or require("WhisperMessenger.UI.Theme.Colors")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local Layout = ns.ThemeLayout or require("WhisperMessenger.UI.Theme.Layout")
local ThemeTextures = ns.ThemeTextures or require("WhisperMessenger.UI.Theme.Textures")
local ThemePresets = ns.ThemePresets or require("WhisperMessenger.UI.Theme.Presets")

local Theme = {}
Theme.DEFAULT_PRESET = ThemePresets.WOW_DEFAULT or "wow_default"
local activePresetKey = Theme.DEFAULT_PRESET
local function isValidColorToken(token)
  return type(token) == "table"
    and type(token[1]) == "number"
    and type(token[2]) == "number"
    and type(token[3]) == "number"
    and type(token[4]) == "number"
end

local function canApplyPreset(preset)
  if type(preset) ~= "table" then
    return false
  end

  for key, current in pairs(Theme.COLORS) do
    if type(current) ~= "table" or not isValidColorToken(preset[key]) then
      return false
    end
  end

  return true
end

local function applyPresetColors(preset)
  for key, current in pairs(Theme.COLORS) do
    local token = preset[key]
    current[1] = token[1]
    current[2] = token[2]
    current[3] = token[3]
    current[4] = token[4]
  end
end

-- Legacy flat constants
Theme.TITLE = "WM"
Theme.WINDOW_IDLE_ALPHA = 1
Theme.WINDOW_EXTERNAL_ACTIVITY_ALPHA = 0.72
Theme.WINDOW_ALPHA_FADE_SECONDS = 0.12
Theme.WINDOW_ALPHA_UPDATE_INTERVAL = 0.1

Theme.COLORS = Colors
Theme.FONTS = Fonts
Theme.LAYOUT = Layout
Theme.TEXTURES = ThemeTextures.TEXTURES
Theme.ClassIcon = ThemeTextures.ClassIcon
Theme.FactionIcon = ThemeTextures.FactionIcon

local BubbleColors = ns.ThemeBubbleColors
if type(BubbleColors) ~= "table" and type(require) == "function" then
  local ok, mod = pcall(require, "WhisperMessenger.UI.Theme.BubbleColors")
  if ok and type(mod) == "table" then
    BubbleColors = mod
  end
end

function Theme.ListPresets()
  return ThemePresets.ListKeys()
end

function Theme.GetPreset()
  return activePresetKey
end

function Theme.SetPreset(presetKey)
  local preset = ThemePresets.Get(presetKey)
  if not canApplyPreset(preset) then
    return false
  end

  applyPresetColors(preset)
  activePresetKey = presetKey

  -- Re-apply custom bubble colors if a non-default bubble preset is active
  if BubbleColors and BubbleColors.ApplyPreset then
    BubbleColors.ApplyPreset()
  end

  return true
end

function Theme.ResolvePreset(requestedKey, trace)
  local fallbackKey = Theme.DEFAULT_PRESET
  local targetKey = requestedKey or fallbackKey

  if Theme.SetPreset(targetKey) then
    return targetKey, true
  end

  if targetKey ~= fallbackKey and Theme.SetPreset(fallbackKey) then
    if trace then
      trace("theme preset fallback", tostring(targetKey), "->", tostring(fallbackKey))
    end
    return fallbackKey, true
  end

  local activeKey = Theme.GetPreset() or fallbackKey
  if trace then
    trace("theme preset apply failed", tostring(targetKey), "active=" .. tostring(activeKey))
  end
  return activeKey, false
end

function Theme.ListBubblePresets()
  if BubbleColors and BubbleColors.ListPresets then
    return BubbleColors.ListPresets()
  end
  return { "default" }
end

function Theme.GetBubblePreset()
  if BubbleColors and BubbleColors.GetPreset then
    return BubbleColors.GetPreset()
  end
  return "default"
end

function Theme.SetBubblePreset(presetKey)
  if BubbleColors and BubbleColors.SetPreset then
    return BubbleColors.SetPreset(presetKey)
  end
  return false
end

-- Backward-compatible flat aliases
Theme.WINDOW_WIDTH = Layout.WINDOW_WIDTH
Theme.WINDOW_HEIGHT = Layout.WINDOW_HEIGHT
Theme.CONTACTS_WIDTH = Layout.CONTACTS_WIDTH
Theme.TOP_BAR_HEIGHT = Layout.TOP_BAR_HEIGHT
Theme.CONTENT_PADDING = Layout.CONTENT_PADDING
Theme.COMPOSER_HEIGHT = Layout.COMPOSER_HEIGHT
Theme.DIVIDER_THICKNESS = Layout.DIVIDER_THICKNESS

ns.Theme = Theme
return Theme
