local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Tells whether a system chat line is one player's /who row.
local WhoRow = {}

-- Every locale's /who line ends with "- <area>" (ruRU without a guild: an en
-- dash), so only that tail counts: the same name inside a race, guild or
-- longer zone must not.
local EN_DASH = "\226\128\147"

local function endsWithArea(systemText, area)
  local tail = " " .. area
  if #systemText <= #tail or string.sub(systemText, -#tail) ~= tail then
    return false
  end
  local head = string.sub(systemText, 1, #systemText - #tail)
  return string.sub(head, -1) == "-" or string.sub(head, -#EN_DASH) == EN_DASH
end

-- A system line is one player's /who row: `[Name]` or `[Name-Realm]` plus the
-- area. Plain finds only; names and areas are player data, not patterns.
function WhoRow.Matches(systemText, info)
  if type(systemText) ~= "string" then
    return false
  end
  local shortName = string.match(info.fullName, "^[^-]+") or info.fullName
  local open = "[" .. shortName
  local from = 1
  while true do
    local _, last = string.find(systemText, open, from, true)
    if last == nil then
      return false
    end
    local nextChar = string.sub(systemText, last + 1, last + 1)
    if nextChar == "]" or nextChar == "-" then
      return endsWithArea(systemText, info.area)
    end
    from = last + 1
  end
end

ns.WhoRow = WhoRow

return WhoRow
