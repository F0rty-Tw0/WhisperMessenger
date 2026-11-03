local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Text color presets for the font color setting. "default" has no color:
-- each text keeps its theme color.
local FontColors = {}

local PRESETS = {
  default = { key = "default", label = "Default", rgba = nil },
  gold = { key = "gold", label = "Gold", rgba = { 1, 0.82, 0, 1 } },
  light_blue = { key = "light_blue", label = "Blue", rgba = { 0.67, 0.85, 1, 1 } },
  soft_green = { key = "soft_green", label = "Green", rgba = { 0.67, 1, 0.67, 1 } },
  purple = { key = "purple", label = "Purple", rgba = { 0.78, 0.61, 1, 1 } },
  rose = { key = "rose", label = "Rose", rgba = { 1, 0.65, 0.75, 1 } },
}

local ORDER = { "default", "gold", "light_blue", "soft_green", "purple", "rose" }

-- The preset for `key`, or nil when there is none.
function FontColors.Get(key)
  return PRESETS[key]
end

-- Copies of every preset, in menu order.
function FontColors.List()
  local list = {}
  for _, key in ipairs(ORDER) do
    local preset = PRESETS[key]
    list[#list + 1] = { key = preset.key, label = preset.label, rgba = preset.rgba }
  end
  return list
end

ns.ThemeFontColors = FontColors
return FontColors
