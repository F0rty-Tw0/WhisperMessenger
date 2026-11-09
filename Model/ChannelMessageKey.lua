local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

local ChannelMessageKey = {}

local REALM_NOISE = "[ %-']"

-- A secret name reads as empty, so it is never stored. Checked before any
-- comparison: comparing a secret logs a blocked action in taint.log.
function ChannelMessageKey.Normalize(name)
  if SecretValue.Is(name) or type(name) ~= "string" then
    return ""
  end

  local lowered = string.lower(name)
  local base, realm = string.match(lowered, "^([^-]*)-(.*)$")
  if base == nil then
    return lowered
  end

  local cleanRealm = string.gsub(realm, REALM_NOISE, "")
  if cleanRealm == "" then
    return base
  end

  return base .. "-" .. cleanRealm
end

function ChannelMessageKey.Base(key)
  return string.match(key, "^([^-]+)") or key
end

function ChannelMessageKey.HasRealm(key)
  return ChannelMessageKey.Base(key) ~= key
end

ns.ChannelMessageKey = ChannelMessageKey
return ChannelMessageKey
