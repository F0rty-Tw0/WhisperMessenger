local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IgnoreCheck = {}

local function callBool(fn, arg)
  local ok, result = pcall(fn, arg)
  return ok and result == true
end

-- Returns true when the local player has the given character on their
-- C_FriendList ignore list. Battle.net whispers (channel == "BN") use a
-- separate block system and are out of scope here — callers should skip
-- the check for that channel.
function IgnoreCheck.IsContactIgnored(api, displayName, guid)
  if type(api) ~= "table" then
    return false
  end
  if guid and guid ~= "" and type(api.IsIgnoredByGuid) == "function" then
    if callBool(api.IsIgnoredByGuid, guid) then
      return true
    end
  end
  if type(displayName) == "string" and displayName ~= "" and type(api.IsIgnored) == "function" then
    if callBool(api.IsIgnored, displayName) then
      return true
    end
  end
  return false
end

ns.IgnoreCheck = IgnoreCheck

return IgnoreCheck
