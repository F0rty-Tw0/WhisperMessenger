local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The keys a player has bound to a game action, for override bindings.
local BindingKeys = {}

-- getBindingKey is GetBindingKey or a stand-in; it returns every slot.
function BindingKeys.ForAction(getBindingKey, action)
  local keys = {}
  if type(getBindingKey) ~= "function" then
    return keys
  end
  local raw = { getBindingKey(action) }
  for i = 1, #raw do
    if type(raw[i]) == "string" and raw[i] ~= "" then
      table.insert(keys, raw[i])
    end
  end
  return keys
end

ns.BindingKeys = BindingKeys

return BindingKeys
