local Types = require("WhisperMessenger.Transport.Types")

-- Test runners may register the module under its full or its short name.
local MODULE_NAMES = { "WhisperMessenger.Transport.Types", "Transport.Types" }

local function reloadWithEnum(enum)
  local savedEnum = _G.Enum
  local saved = {}
  for _, name in ipairs(MODULE_NAMES) do
    saved[name] = package.loaded[name]
    package.loaded[name] = nil
  end
  _G.Enum = enum
  local ok, reloaded = pcall(require, MODULE_NAMES[1])
  _G.Enum = savedEnum
  for _, name in ipairs(MODULE_NAMES) do
    package.loaded[name] = saved[name]
  end
  assert(ok, reloaded)

  return reloaded
end

return function()
  -- AVAILABILITY_STATUS_BY_CODE (Enum.ChatWhisperTargetStatus: CanWhisper, CanWhisperGuild, Offline, WrongFaction)
  assert(Types.AVAILABILITY_STATUS_BY_CODE[0] == "CanWhisper")
  assert(Types.AVAILABILITY_STATUS_BY_CODE[1] == "CanWhisperGuild", "code 1 is CanWhisperGuild: kept apart from CanWhisper")
  assert(Types.AVAILABILITY_STATUS_BY_CODE[2] == "Offline", "code 2 is Offline in the game's enum")
  assert(Types.AVAILABILITY_STATUS_BY_CODE[3] == "WrongFaction", "code 3 is WrongFaction in the game's enum")

  -- The game's enum wins over the built-in literals when present
  local fromEnum = reloadWithEnum({
    ChatWhisperTargetStatus = { CanWhisper = 10, CanWhisperGuild = 11, Offline = 12, WrongFaction = 13 },
  })
  assert(fromEnum.AVAILABILITY_STATUS_BY_CODE[10] == "CanWhisper")
  assert(fromEnum.AVAILABILITY_STATUS_BY_CODE[11] == "CanWhisperGuild")
  assert(fromEnum.AVAILABILITY_STATUS_BY_CODE[12] == "Offline")
  assert(fromEnum.AVAILABILITY_STATUS_BY_CODE[13] == "WrongFaction")
  assert(fromEnum.AVAILABILITY_STATUS_BY_CODE[2] == nil, "literal codes must not leak in when the enum exists")

  -- An enum missing a name falls back to that name's literal code
  local partial = reloadWithEnum({ ChatWhisperTargetStatus = { Offline = 12 } })
  assert(partial.AVAILABILITY_STATUS_BY_CODE[12] == "Offline")
  assert(partial.AVAILABILITY_STATUS_BY_CODE[3] == "WrongFaction", "missing WrongFaction falls back to literal 3")

  -- A literal fallback never overwrites a code the real enum already uses
  local collide = reloadWithEnum({ ChatWhisperTargetStatus = { CanWhisperGuild = 2, Offline = 3 } })
  assert(collide.AVAILABILITY_STATUS_BY_CODE[2] == "CanWhisperGuild")
  assert(collide.AVAILABILITY_STATUS_BY_CODE[3] == "Offline", "literal WrongFaction (3) must not overwrite the enum's Offline")

  -- WHISPERABLE
  assert(Types.WHISPERABLE.CanWhisperGuild == true, "CanWhisperGuild is whisperable")
  assert(Types.WHISPERABLE.CanWhisper == true)
  assert(Types.WHISPERABLE.XFaction == true, "XFaction (computed) should be whisperable")
  assert(Types.WHISPERABLE.Away == true)
  assert(Types.WHISPERABLE.Busy == true)
  assert(Types.WHISPERABLE.WrongFaction == nil, "WrongFaction should not be whisperable")
  assert(Types.WHISPERABLE.Offline == nil)
end
