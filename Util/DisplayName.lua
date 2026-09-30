local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- How a contact's name appears on screen. Stored names (BattleTags,
-- conversation keys) stay whole; only the shown text changes.
local DisplayName = {}

local hideBattleTagNumbers = true
-- Lowercased name parts that two different Battle.net friends share.
local clashingNames = {}
-- Bumped whenever Format's output could change, so cached renders repaint.
local revision = 0

local function battleTagName(name)
  return string.match(name, "^(.+)#%d+$")
end

function DisplayName.Configure(opts)
  if type(opts) ~= "table" or type(opts.hideBattleTagNumbers) ~= "boolean" then
    return
  end
  if opts.hideBattleTagNumbers ~= hideBattleTagNumbers then
    hideBattleTagNumbers = opts.hideBattleTagNumbers
    revision = revision + 1
  end
end

-- battleTags: every stored Battle.net friend's BattleTag. A name part two
-- different friends share keeps its number so they stay tellable apart.
function DisplayName.SetBattleTags(battleTags)
  local firstTagByName = {}
  local nextClashes = {}
  for _, tag in ipairs(battleTags or {}) do
    local base = type(tag) == "string" and battleTagName(tag)
    if base then
      local key = string.lower(base)
      local lowerTag = string.lower(tag)
      local first = firstTagByName[key]
      if first == nil then
        firstTagByName[key] = lowerTag
      elseif first ~= lowerTag then
        nextClashes[key] = true
      end
    end
  end

  local changed = false
  for key in pairs(nextClashes) do
    changed = changed or not clashingNames[key]
  end
  for key in pairs(clashingNames) do
    changed = changed or not nextClashes[key]
  end
  clashingNames = nextClashes
  if changed then
    revision = revision + 1
  end
end

function DisplayName.Revision()
  return revision
end

-- "Name#1234" shows as "Name" while the BattleTag-numbers option is on,
-- unless another friend's BattleTag has the same name part.
-- Character names ("Name-Realm") never carry a "#" and pass through.
function DisplayName.Format(name)
  if not hideBattleTagNumbers or type(name) ~= "string" then
    return name
  end
  local base = battleTagName(name)
  if base == nil or clashingNames[string.lower(base)] then
    return name
  end
  return base
end

ns.DisplayName = DisplayName
return DisplayName
