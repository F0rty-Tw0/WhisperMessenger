local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = {
  ADDON_NAME = addonName or "WhisperMessenger",
  VERSION = "0.1.0",

  LIVE_EVENT_NAMES = {
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_AFK",
    "CHAT_MSG_DND",
    "CAN_LOCAL_WHISPER_TARGET_RESPONSE",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE",
  },

  AVAILABILITY_STATUS_BY_CODE = {
    [0] = "CanWhisper",
    [1] = "Offline",
    [2] = "WrongFaction",
  },
}

ns.Constants = Constants

return Constants
