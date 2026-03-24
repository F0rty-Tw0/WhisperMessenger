-- .luacheckrc for WhisperMessenger (WoW Retail Addon)
-- Targets Lua 5.1 (WoW runtime)

std = "lua51"
max_line_length = false   -- StyLua handles formatting; luacheck handles semantics
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
  "11./BINDING_.*",    -- keybinding globals are expected
  "11./SLASH_.*",      -- slash command globals are expected
  "212/self",          -- unused 'self' in method definitions
  "212/event",         -- unused 'event' in OnEvent handlers
  "212/elapsed",       -- unused 'elapsed' in OnUpdate handlers
  "211/addonName",     -- unused first return from `local addonName, ns = ...`
  "212/addonName",     -- same when treated as argument
  "331/ns",            -- ns is set (mutated) then exported, not read directly
  "122/_G",            -- writing SavedVariables via _G.VarName is intentional
  "143/table",         -- table.unpack exists in Lua 5.2+; WoW provides compat
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
  "UIParent",

  -- Namespaced C_ APIs (used by WhisperMessenger)
  "C_ChatInfo",
  "C_BattleNet",
  "C_Timer",
  "C_FriendList",

  -- Unit and player info
  "UnitName",
  "UnitFullName",
  "UnitGUID",
  "GetPlayerInfoByGUID",
  "GetNormalizedRealmName",
  "GetRealmName",
  "Ambiguate",
  "IsLoggedIn",

  -- Error handling and hooks
  "geterrorhandler",
  "seterrorhandler",
  "securecall",
  "hooksecurefunc",

  -- Misc
  "GetTime",
  "GetServerTime",
  "GetAddOnMetadata",
  "InCombatLockdown",
  "PlaySound",
  "print",

  -- UI constants
  "RAID_CLASS_COLORS",

  -- Standard globals
  "_G",
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
    "111",  -- setting undefined global (tests stub globals)
    "112",  -- mutating undefined global
    "113",  -- accessing undefined global
    "142",  -- setting undefined field of global (table.unpack stubs)
    "143",  -- accessing undefined field of global (table.unpack)
    "211",  -- unused local variable
    "212",  -- unused argument
    "421",  -- shadowing local variable
    "431",  -- shadowing upvalue
    "432",  -- shadowing upvalue argument (common in fake_ui self patterns)
  },
}
