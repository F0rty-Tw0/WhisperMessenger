local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Colours a player's level by how it compares to the player's own level,
-- like the quest log (grey trivial ... red very hard).
local LevelColor = {}

-- Pcalled with the level, so a missing or throwing API or an odd result
-- falls back instead of erroring.
local function readColor(level)
  local c = _G.GetQuestDifficultyColor(level)
  if type(c) == "table" and type(c.r) == "number" then
    return c
  end
end

-- "|cffRRGGBB" escape for the level text; never nil. Close it with "|r".
function LevelColor.Escape(level)
  local ok, c = pcall(readColor, level)
  if ok and c then
    return UIHelpers.colorEscape({ c.r, c.g, c.b })
  end
  return UIHelpers.colorEscape(Theme.COLORS.text_secondary)
end

ns.LevelColor = LevelColor
return LevelColor
