local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

local InstanceName = {}

-- Current returns the name of the dungeon, raid or battleground the player
-- is in, or nil outside an instance, when the API is missing or raises, or
-- when the name is a 12.0 secret value.
function InstanceName.Current()
  local ok, inInstance = pcall(_G.IsInInstance)
  if not ok or not inInstance then
    return nil
  end

  local infoOk, name = pcall(_G.GetInstanceInfo)
  -- Secret first: a secret raises on the == "" below.
  if not infoOk or SecretValue.Is(name) or type(name) ~= "string" or name == "" then
    return nil
  end

  return name
end

ns.GroupChatIngestInstanceName = InstanceName
return InstanceName
