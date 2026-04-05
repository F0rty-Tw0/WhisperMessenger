local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BubbleColors = {}

local PRESET_DEFAULT = "default"
local activePresetKey = PRESET_DEFAULT

local presetOrder = {
  "default",
  "shadow",
  "ember",
  "arcane",
  "frost",
  "fel",
}

-- Custom bubble color palettes (in/out/system).
-- "default" is a sentinel — it means "use whatever the theme provides".
local presetData = {
  shadow = {
    bg_bubble_in = { 0.16, 0.17, 0.20, 0.95 },
    bg_bubble_out = { 0.13, 0.16, 0.20, 0.88 },
    bg_bubble_system = { 0.10, 0.10, 0.12, 0.78 },
  },
  ember = {
    bg_bubble_in = { 0.24, 0.18, 0.14, 0.90 },
    bg_bubble_out = { 0.55, 0.30, 0.18, 0.84 },
    bg_bubble_system = { 0.24, 0.18, 0.12, 0.72 },
  },
  arcane = {
    bg_bubble_in = { 0.22, 0.14, 0.30, 0.92 },
    bg_bubble_out = { 0.36, 0.18, 0.48, 0.85 },
    bg_bubble_system = { 0.16, 0.12, 0.22, 0.70 },
  },
  frost = {
    bg_bubble_in = { 0.18, 0.22, 0.30, 0.92 },
    bg_bubble_out = { 0.28, 0.42, 0.58, 0.82 },
    bg_bubble_system = { 0.14, 0.16, 0.20, 0.68 },
  },
  fel = {
    bg_bubble_in = { 0.10, 0.22, 0.12, 0.90 },
    bg_bubble_out = { 0.14, 0.38, 0.16, 0.82 },
    bg_bubble_system = { 0.08, 0.16, 0.10, 0.68 },
  },
}

local BUBBLE_KEYS = { "bg_bubble_in", "bg_bubble_out", "bg_bubble_system" }

local function getThemeColors()
  local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
  if type(Theme) ~= "table" or type(Theme.COLORS) ~= "table" then
    return nil
  end
  return Theme.COLORS
end

local function getThemePresetBubbleColors()
  local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
  if type(Theme) ~= "table" or type(Theme.GetPreset) ~= "function" then
    return nil
  end
  local Presets = ns.ThemePresets or require("WhisperMessenger.UI.Theme.Presets")
  if type(Presets) ~= "table" or type(Presets.Get) ~= "function" then
    return nil
  end
  local activeKey = Theme.GetPreset()
  local palette = Presets.Get(activeKey)
  if type(palette) ~= "table" then
    return nil
  end
  return palette
end

local function applyColorTable(target, source)
  target[1] = source[1]
  target[2] = source[2]
  target[3] = source[3]
  target[4] = source[4]
end

function BubbleColors.ListPresets()
  local keys = {}
  for i, key in ipairs(presetOrder) do
    keys[i] = key
  end
  return keys
end

function BubbleColors.GetPreset()
  return activePresetKey
end

function BubbleColors.SetPreset(presetKey)
  if presetKey == PRESET_DEFAULT then
    activePresetKey = PRESET_DEFAULT
    -- Restore the active theme preset's bubble colors
    local colors = getThemeColors()
    local palette = getThemePresetBubbleColors()
    if colors and palette then
      for _, key in ipairs(BUBBLE_KEYS) do
        local target = colors[key]
        local source = palette[key]
        if type(target) == "table" and type(source) == "table" then
          applyColorTable(target, source)
        end
      end
    end
    return true
  end

  local palette = presetData[presetKey]
  if type(palette) ~= "table" then
    return false
  end

  activePresetKey = presetKey

  local colors = getThemeColors()
  if not colors then
    return true
  end

  for _, key in ipairs(BUBBLE_KEYS) do
    local target = colors[key]
    local source = palette[key]
    if type(target) == "table" and type(source) == "table" then
      applyColorTable(target, source)
    end
  end

  return true
end

-- Re-apply the active bubble preset onto Theme.COLORS.
-- Call this after a theme preset switch so custom bubble colors survive.
function BubbleColors.ApplyPreset()
  if activePresetKey == PRESET_DEFAULT then
    return
  end

  local palette = presetData[activePresetKey]
  if type(palette) ~= "table" then
    return
  end

  local colors = getThemeColors()
  if not colors then
    return
  end

  for _, key in ipairs(BUBBLE_KEYS) do
    local target = colors[key]
    local source = palette[key]
    if type(target) == "table" and type(source) == "table" then
      applyColorTable(target, source)
    end
  end
end

function BubbleColors.GetColors()
  local colors = getThemeColors()
  if not colors then
    return {}
  end

  return {
    bg_bubble_in = {
      colors.bg_bubble_in[1],
      colors.bg_bubble_in[2],
      colors.bg_bubble_in[3],
      colors.bg_bubble_in[4],
    },
    bg_bubble_out = {
      colors.bg_bubble_out[1],
      colors.bg_bubble_out[2],
      colors.bg_bubble_out[3],
      colors.bg_bubble_out[4],
    },
    bg_bubble_system = {
      colors.bg_bubble_system[1],
      colors.bg_bubble_system[2],
      colors.bg_bubble_system[3],
      colors.bg_bubble_system[4],
    },
  }
end

ns.ThemeBubbleColors = BubbleColors
return BubbleColors
