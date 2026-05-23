local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Wrapper around `C_ChatInfo.RegisterAddonMessagePrefix` and
-- `C_ChatInfo.SendAddonMessage`. Handles missing API gracefully (returns
-- `false`) and tracks registered prefixes to keep registration idempotent.
--
-- Blizzard caps the payload at 255 bytes per call. We refuse oversized
-- payloads here so the caller is forced to batch or skip; we never want a
-- thrown error to tear down the surrounding character whisper which has
-- already succeeded on its own.

local AddonComm = {}

local MAX_PAYLOAD_BYTES = 255

local registeredPrefixes = {}

local function resolveRegister(api)
  if type(api) == "table" and type(api.RegisterAddonMessagePrefix) == "function" then
    return api.RegisterAddonMessagePrefix
  end
  return nil
end

local function resolveSend(api)
  if type(api) == "table" and type(api.SendAddonMessage) == "function" then
    return api.SendAddonMessage
  end
  return nil
end

local function resolveSendBNet(api)
  if type(api) == "table" and type(api.SendGameData) == "function" then
    return api.SendGameData
  end
  if type(_G.BNSendGameData) == "function" then
    return _G.BNSendGameData
  end
  return nil
end

function AddonComm.RegisterPrefix(api, prefix)
  if type(prefix) ~= "string" or prefix == "" then
    return false
  end

  local register = resolveRegister(api)
  if register == nil then
    -- Without an API we can't validate the registration. Report failure
    -- regardless of prior state so the caller knows the wire is unusable.
    return false
  end

  if registeredPrefixes[prefix] then
    return true
  end

  local ok = pcall(register, prefix)
  if not ok then
    return false
  end

  registeredPrefixes[prefix] = true
  return true
end

function AddonComm.Send(api, prefix, payload, target)
  if type(prefix) ~= "string" or prefix == "" then
    return false
  end
  if type(payload) ~= "string" or payload == "" then
    return false
  end
  if #payload > MAX_PAYLOAD_BYTES then
    return false
  end
  if type(target) ~= "string" or target == "" then
    return false
  end

  local send = resolveSend(api)
  if send == nil then
    return false
  end

  local ok = pcall(send, prefix, payload, "WHISPER", target)
  return ok
end

function AddonComm.SendBNet(api, prefix, payload, bnetAccountID)
  if type(prefix) ~= "string" or prefix == "" then
    return false
  end
  if type(payload) ~= "string" or payload == "" then
    return false
  end
  if #payload > MAX_PAYLOAD_BYTES then
    return false
  end
  if bnetAccountID == nil then
    return false
  end

  local send = resolveSendBNet(api)
  if send == nil then
    return false
  end

  local ok = pcall(send, bnetAccountID, prefix, payload)
  return ok
end

AddonComm.MAX_PAYLOAD_BYTES = MAX_PAYLOAD_BYTES

ns.AddonComm = AddonComm

return AddonComm
