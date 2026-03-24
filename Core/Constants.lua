local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = {
  ADDON_NAME = addonName or "WhisperMessenger",
  VERSION = "v1.0.1",

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

  LIFECYCLE_EVENT_NAMES = {
    "BN_FRIEND_LIST_SIZE_CHANGED",
    "BN_FRIEND_INFO_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT",
    "GUILD_ROSTER_UPDATE",
    "CLUB_MEMBER_UPDATED",
    "CLUB_MEMBER_ADDED",
    "CLUB_MEMBER_REMOVED",
  },
}

ns.Constants = Constants

return Constants
