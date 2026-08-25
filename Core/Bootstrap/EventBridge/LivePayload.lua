local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")

local LivePayload = {}

function LivePayload.Build(runtime, eventName, ...)
  if eventName == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
    local guid, status = ...
    return {
      guid = guid,
      status = BNetResolver.NormalizeAvailabilityStatus(status),
      rawStatus = status,
    }
  end

  if eventName == "CHAT_MSG_ADDON" then
    local prefix, message, channel, sender = ...
    return {
      prefix = prefix,
      text = message,
      channel = channel,
      playerName = sender,
    }
  end

  if eventName == "BN_CHAT_MSG_ADDON" then
    local prefix, message, channel, rawGameAccountID = ...
    local gameAccountID = BNetResolver.SanitizeAccountID(rawGameAccountID)
    local accountInfo
    if gameAccountID ~= nil then
      accountInfo = BNetResolver.ResolveAccountInfoByGameAccountID(runtime and runtime.bnetApi or _G.C_BattleNet or {}, gameAccountID)
    end
    return {
      prefix = prefix,
      text = message,
      channel = channel,
      gameAccountID = gameAccountID,
      bnetAccountID = accountInfo and accountInfo.bnetAccountID or nil,
      accountInfo = accountInfo,
    }
  end

  if eventName == "CHAT_MSG_BN_WHISPER" or eventName == "CHAT_MSG_BN_WHISPER_INFORM" or eventName == "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE" then
    local text, playerName, _, _, _, _, _, _, _, _, lineID, guid, rawBnetAccountID = ...
    local bnetAccountID = BNetResolver.SanitizeAccountID(rawBnetAccountID)
    local accountInfo
    if bnetAccountID ~= nil then
      accountInfo = BNetResolver.ResolveAccountInfo(runtime and runtime.bnetApi or _G.C_BattleNet or {}, bnetAccountID, guid)
    end
    -- Resolve classTag/raceTag via GetPlayerInfoByGUID (BNet API only provides localized className)
    local playerGuid = accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.playerGuid or guid
    local playerInfo = BNetResolver.ResolvePlayerInfo(runtime and runtime.playerInfoByGUID or nil, playerGuid)
    return {
      text = text,
      playerName = playerName,
      lineID = lineID,
      -- Prefer the resolved playerGuid from the BNet API over the raw event
      -- guid, which may belong to a different player's character.
      guid = playerGuid,
      channel = "BN",
      bnetAccountID = bnetAccountID,
      accountInfo = accountInfo,
      playerInfo = playerInfo,
    }
  end

  local text, playerName, _, _, _, _, _, _, _, _, lineID, guid = ...
  return {
    text = text,
    playerName = playerName,
    lineID = lineID,
    guid = guid,
    playerInfo = BNetResolver.ResolvePlayerInfo(runtime and runtime.playerInfoByGUID or nil, guid),
  }
end

ns.BootstrapEventBridgeLivePayload = LivePayload

return LivePayload
