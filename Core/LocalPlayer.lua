local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The logged-in character's short name and class tag, read live. Both
-- return nil when the API is missing, throws, or reports nothing.
local LocalPlayer = {}

local function nonEmpty(value)
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

ns.LocalPlayer = LocalPlayer
return LocalPlayer
