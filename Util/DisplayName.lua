local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- How a contact's name appears on screen. Stored names (BattleTags,
-- conversation keys) stay whole; only the shown text changes.
local DisplayName = {}

local hideBattleTagNumbers = true

function DisplayName.Configure(opts)
  if type(opts) == "table" and type(opts.hideBattleTagNumbers) == "boolean" then
    hideBattleTagNumbers = opts.hideBattleTagNumbers
  end
end

-- "Name#1234" shows as "Name" while the BattleTag-numbers option is on.
-- Character names ("Name-Realm") never carry a "#" and pass through.
function DisplayName.Format(name)
  if not hideBattleTagNumbers or type(name) ~= "string" then
    return name
  end
  return string.match(name, "^(.+)#%d+$") or name
end

ns.DisplayName = DisplayName
return DisplayName
