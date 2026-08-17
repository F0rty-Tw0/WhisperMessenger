local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BNetIdentity = {}

local function validAccountID(value)
  if type(value) == "number" then
    return value > 0
  end
  return type(value) == "string" and value ~= ""
end

function BNetIdentity.ResolveLocalAccountID(existingAccountID, getBNetInfo)
  if validAccountID(existingAccountID) then
    return existingAccountID
  end
  if type(getBNetInfo) ~= "function" then
    return nil
  end

  local ok, accountID = pcall(getBNetInfo)
  if ok and validAccountID(accountID) then
    return accountID
  end
  return nil
end

ns.BNetIdentity = BNetIdentity
return BNetIdentity
