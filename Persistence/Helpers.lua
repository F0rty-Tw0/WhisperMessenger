local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Helpers = {}

-- Apply defaults to a table: for each key in defaults, if target[key] is nil, set it
function Helpers.applyDefaults(target, defaults)
  if target == nil or defaults == nil then
    return target or {}
  end
  for key, value in pairs(defaults) do
    if target[key] == nil then
      target[key] = value
    end
  end
  return target
end

ns.PersistenceHelpers = Helpers
return Helpers
