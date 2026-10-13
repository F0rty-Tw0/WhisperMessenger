local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- 12.0 hands addons secret values (event args, API results) that raise on
-- any comparison. Clients without issecretvalue have none.
local SecretValue = {}

function SecretValue.Is(value)
  local issecretvalue = _G.issecretvalue
  return type(issecretvalue) == "function" and issecretvalue(value) == true
end

ns.SecretValue = SecretValue
return SecretValue
