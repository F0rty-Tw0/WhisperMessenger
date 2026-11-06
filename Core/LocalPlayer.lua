local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- The logged-in character's short name, class tag and normalized realm, read
-- live. Each getter returns nil when the API is missing, throws, reports
-- nothing, or hands back a secret value (a chat lock), which must never be
-- compared. IsSelf returns a boolean: false when it cannot tell.
local LocalPlayer = {}

local function nonEmpty(value)
  if SecretValue.Is(value) then
    return nil
  end
  if type(value) == "string" and value ~= "" then
    return value
  end
  return nil
end

function LocalPlayer.Name()
  if type(_G.UnitName) ~= "function" then
    return nil
  end
  local ok, name = pcall(_G.UnitName, "player")
  return ok and nonEmpty(name) or nil
end

function LocalPlayer.ClassTag()
  if type(_G.UnitClass) ~= "function" then
    return nil
  end
  local ok, _, classTag = pcall(_G.UnitClass, "player")
  return ok and nonEmpty(classTag) or nil
end

function LocalPlayer.NormalizedRealm()
  if type(_G.GetNormalizedRealmName) ~= "function" then
    return nil
  end
  local ok, realm = pcall(_G.GetNormalizedRealmName)
  return ok and nonEmpty(realm) or nil
end

function LocalPlayer.IsSelf(name, guid)
  if guid ~= nil and type(_G.UnitGUID) == "function" then
    -- The compare itself throws on a secret GUID, so it runs inside the pcall.
    local ok, same = pcall(function()
      return _G.UnitGUID("player") == guid
    end)
    if ok and same then
      return true
    end
  end
  local own = LocalPlayer.Name()
  if own == nil then
    return false
  end
  local realm = LocalPlayer.NormalizedRealm()
  return name == own or (realm ~= nil and name == own .. "-" .. realm)
end

ns.LocalPlayer = LocalPlayer
return LocalPlayer
