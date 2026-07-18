-- .luacheckrc for WhisperMessenger (WoW Retail Addon)
-- Targets Lua 5.1 (WoW runtime)

std = "lua51"
max_line_length = false -- StyLua handles formatting; luacheck handles semantics
cache = true
jobs = 4

-- Exclude vendored/generated/test-infra files
exclude_files = {
  "Libs/",
  "libs/",
  ".luacheckrc",
}

-- Warnings to suppress for common WoW addon patterns
ignore = {
  "11./BINDING_.*", -- keybinding globals are expected
  "11./SLASH_.*", -- slash command globals are expected
  "212/self", -- unused 'self' in method definitions
  "212/event", -- unused 'event' in OnEvent handlers
  "212/elapsed", -- unused 'elapsed' in OnUpdate handlers
  "211/addonName", -- unused first return from `local addonName, ns = ...`
  "212/addonName", -- same when treated as argument
  "331/ns", -- ns is set (mutated) then exported, not read directly
  "122/_G", -- writing SavedVariables via _G.VarName is intentional
  "143/table", -- table.unpack exists in Lua 5.2+; WoW provides compat
}

-- Globals the addon WRITES
globals = {
  -- SavedVariables (declared in .toc)
  "WhisperMessengerDB",
  "WhisperMessengerCharacterDB",

  -- Slash command registration (Blizzard pattern)
  "SlashCmdList",
  "SLASH_WHISPERMESSENGER1",
  "SLASH_WHISPERMESSENGER2",

  -- Keybinding toggle (called from Bindings.xml)
  "WhisperMessenger_Toggle",
}

-- Globals the addon READS (WoW API surface used by this addon)
read_globals = {
  -- Lua 5.1 extras provided by WoW
  "wipe",
  "tinsert",
  "tremove",
  "strjoin",
  "strsplit",
  "strtrim",
  "format",
  "date",
  "time",
  "unpack",

  -- Core frame/widget API
  "CreateFrame",
  "CreateFont",
  "UIParent",
  "Minimap",
  "GameTooltip",
  "GetMinimapShape",
  "GetCursorPosition",
  "GetMouseFocus",
  "IsMouseButtonDown",
  "IsMouselooking",
  "UISpecialFrames",

  -- Library loader (optional dependency for LibDataBroker displays)
  "LibStub",

  -- Dropdown / popup / menu API
  "EasyMenu",
  "ToggleDropDownMenu",
  "UIDropDownMenu_AddButton",
  "UIDropDownMenu_CreateInfo",
  "UIDropDownMenu_Initialize",
  "UnitPopup_OpenMenu",
  "StaticPopupDialogs",
  "StaticPopup_Show",
  "StaticPopup1EditBox",
  "FriendsFrame_ShowBNDropdown",
  "FriendsFrame_ShowDropdown",

  -- Key bindings
  "GetBindingKey",
  "SetOverrideBindingClick",
  "ClearOverrideBindings",

  -- Namespaced C_ APIs (used by WhisperMessenger)
  "C_ChatInfo",
  "C_BattleNet",
  "C_Timer",
  "C_FriendList",
  "C_Club",
  "C_Clipboard",
  "C_DateAndTime",
  "C_RestrictedActions",

  -- Unit and player info
  "UnitName",
  "UnitFullName",
  "UnitGUID",
  "UnitClass",
  "UnitFactionGroup",
  "UnitIsConnected",
  "GetPlayerInfoByGUID",
  "GetNormalizedRealmName",
  "GetRealmName",
  "GetUnitSpeed",
  "Ambiguate",
  "IsLoggedIn",

  -- Error handling and hooks
  "geterrorhandler",
  "seterrorhandler",
  "securecall",
  "hooksecurefunc",
  "ChatFrame_AddMessageEventFilter",
  "ChatFrame_RemoveMessageEventFilter",
  "ChatEdit_SetLastTellTarget",
  "BNGetNumFriends",
  "BNGetNumConversations",
  "BNGetConversationInfo",
  "ChatEdit_DeactivateChat",
  "ChatEdit_UpdateHeader",
  "ChatFrameUtil",
  "ChatFrame_OpenChat",
  "ChatFrame_ReplyTell",
  "ChatFrame_SendBNetTell",
  "ChatFrame_SendTell",
  "ChatEdit_GetActiveWindow",
  "ChatEdit_InsertLink",
  "SetItemRef",
  "SendChatMessage",
  "BNSendWhisper",
  "BNSendConversationMessage",
  "BNSendGameData",
  "BNGetNumConversationMembers",
  "BNGetConversationMemberInfo",
  "NUM_CHAT_WINDOWS",

  -- CVar API
  "GetCVar",
  "SetCVar",

  -- Misc
  "GetTime",
  "GetServerTime",
  "GetAddOnMetadata",
  "GetInstanceInfo",
  "GetLocale",
  "GetChannelName",
  "GetGuildInfo",
  "GetNumGroupMembers",
  "InCombatLockdown",
  "IsInGroup",
  "IsInRaid",
  "IsInGuild",
  "PlaySound",
  "print",
  "UpdateAddOnMemoryUsage",
  "GetAddOnMemoryUsage",

  -- UI constants
  "RAID_CLASS_COLORS",

  -- Standard globals
  "_G",

  -- Flavor detection (multi-TOC Classic support)
  "WOW_PROJECT_ID",
  "WOW_PROJECT_MAINLINE",
  "WOW_PROJECT_CLASSIC",
  "WOW_PROJECT_BURNING_CRUSADE_CLASSIC",
  "WOW_PROJECT_WRATH_CLASSIC",
  "WOW_PROJECT_CATACLYSM_CLASSIC",
  "WOW_PROJECT_MISTS_CLASSIC",
  "LE_EXPANSION_LEVEL_CURRENT",
  "LE_PARTY_CATEGORY_HOME",
  "LE_PARTY_CATEGORY_INSTANCE",
}

-- Test files: allow busted globals and relaxed global access
files["tests/**/*.lua"] = {
  std = "+busted",
  -- Tests stub WoW globals via _G, allow writes
  globals = {
    "_G",
    "CreateFrame",
    "UIParent",
    "C_ChatInfo",
    "C_BattleNet",
    "C_Timer",
    "C_FriendList",
    "SlashCmdList",
    "SLASH_WHISPERMESSENGER1",
    "SLASH_WHISPERMESSENGER2",
    "UnitName",
    "UnitFullName",
    "GetPlayerInfoByGUID",
    "GetNormalizedRealmName",
    "GetRealmName",
    "WhisperMessengerDB",
    "WhisperMessengerCharacterDB",
    "print",
    "date",
    "time",
    "require",
  },
  ignore = {
    "111", -- setting undefined global (tests stub globals)
    "112", -- mutating undefined global
    "113", -- accessing undefined global
    "142", -- setting undefined field of global (table.unpack stubs)
    "143", -- accessing undefined field of global (table.unpack)
    "211", -- unused local variable
    "212", -- unused argument
    "421", -- shadowing local variable
    "431", -- shadowing upvalue
    "432", -- shadowing upvalue argument (common in fake_ui self patterns)
  },
}
