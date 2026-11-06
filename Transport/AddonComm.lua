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

local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local AddonComm = {}

-- Wire prefixes; older addon versions speak these, so never rename them.
AddonComm.PREFIX_REACTION = "WMRX"
AddonComm.PREFIX_QUEST_LINK = "WMQL"
-- Party-free group chats: every line goes to each member as an addon whisper.
AddonComm.PREFIX_GROUP_CHAT = "WMGC"
-- Crafting addons (RobotsDotTxt convention) announce an automated greeting
-- with "Q:<AddonName>" on this prefix. Listen-only: a "D:<delay>" reply asks
-- the sender to fake a human answer, so every send on it is refused.
AddonComm.PREFIX_ADDON_GREETING = "robots.txt"
-- CraftScan's own channel. A customer's client speaks on it right after its
-- "found you" whisper. Listen-only too: WM is not CraftScan.
AddonComm.PREFIX_CRAFT_SCAN = "CRAFT_SCAN"

local RECEIVE_ONLY_PREFIXES = {
  [AddonComm.PREFIX_ADDON_GREETING] = true,
  [AddonComm.PREFIX_CRAFT_SCAN] = true,
}

local MAX_PAYLOAD_BYTES = 255

local function isSendablePrefix(prefix)
  return type(prefix) == "string" and prefix ~= "" and RECEIVE_ONLY_PREFIXES[prefix] ~= true
end

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

local function didSendSucceed(callSucceeded, ...)
  if not callSucceeded then
    return false
  end
  local count = select("#", ...)
  local result
  if count > 0 then
    result = select(count, ...)
  end
  return result == nil or result == true or result == 0
end

local function didRegisterSucceed(callSucceeded, ...)
  if not callSucceeded then
    return false
  end
  local count = select("#", ...)
  local result
  if count > 0 then
    result = select(count, ...)
  end
  return result == nil or result == true or result == 0 or result == 1
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

  local registered = didRegisterSucceed(pcall(register, prefix))
  if not registered then
    return false
  end

  registeredPrefixes[prefix] = true
  return true
end

function AddonComm.Send(api, prefix, payload, target)
  if not isSendablePrefix(prefix) then
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

  return didSendSucceed(pcall(send, prefix, payload, "WHISPER", target))
end

-- The send result codes that mean "too many messages, try again later".
local function isThrottleResult(result)
  local codes = _G.Enum and _G.Enum.SendAddonMessageResult
  local addonThrottle = codes and codes.AddonMessageThrottle or 3
  local channelThrottle = codes and codes.ChannelThrottle or 8
  return result == addonThrottle or result == channelThrottle
end

local function sendOutcome(callSucceeded, ...)
  if not callSucceeded then
    return false, false
  end
  local count = select("#", ...)
  local result
  if count > 0 then
    result = select(count, ...)
  end
  if result == nil or result == true or result == 0 then
    return true, false
  end
  return false, isThrottleResult(result)
end

-- Like Send, but also tells a throttled send (worth trying again) from one
-- the game refused for good. Returns sent, throttled.
function AddonComm.SendWhisperDetailed(api, prefix, payload, target)
  if not isSendablePrefix(prefix) or type(payload) ~= "string" or payload == "" or #payload > MAX_PAYLOAD_BYTES then
    return false, false
  end
  if type(target) ~= "string" or target == "" then
    return false, false
  end
  local send = resolveSend(api)
  if send == nil then
    return false, false
  end
  return sendOutcome(pcall(send, prefix, payload, "WHISPER", target))
end

function AddonComm.SendGroup(api, prefix, payload, channel)
  if not isSendablePrefix(prefix) then
    return false
  end
  if type(payload) ~= "string" or payload == "" then
    return false
  end
  if #payload > MAX_PAYLOAD_BYTES then
    return false
  end
  if ChannelType.ADDON_GROUP_CHANNELS[channel] ~= true then
    return false
  end

  local send = resolveSend(api)
  if send == nil then
    return false
  end

  return didSendSucceed(pcall(send, prefix, payload, channel))
end

function AddonComm.SendBNet(api, prefix, payload, gameAccountID)
  if not isSendablePrefix(prefix) then
    return false
  end
  if type(payload) ~= "string" or payload == "" then
    return false
  end
  if #payload > MAX_PAYLOAD_BYTES then
    return false
  end
  if gameAccountID == nil then
    return false
  end

  local send = resolveSendBNet(api)
  if send == nil then
    return false
  end

  local ok = pcall(send, gameAccountID, prefix, payload)
  return ok
end

ns.AddonComm = AddonComm

return AddonComm
