local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = {
  ADDON_NAME = addonName or "WhisperMessenger",
  VERSION = "v1.1.7",

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

  CHANNEL_EVENT_NAMES = {
    "CHAT_MSG_CHANNEL",
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
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "ZONE_CHANGED_NEW_AREA",
    "ADDON_RESTRICTION_STATE_CHANGED",
  },

  -- Lifecycle events that must stay registered during mythic lockdown
  -- (needed for detecting zone transitions and mythic end).
  MYTHIC_ESSENTIAL_EVENTS = {
    PLAYER_ENTERING_WORLD = true,
    PLAYER_LOGOUT = true,
    CHALLENGE_MODE_START = true,
    CHALLENGE_MODE_COMPLETED = true,
    CHALLENGE_MODE_RESET = true,
    ENCOUNTER_START = true,
    ENCOUNTER_END = true,
    ZONE_CHANGED_NEW_AREA = true,
  },
}

ns.Constants = Constants

return Constants
