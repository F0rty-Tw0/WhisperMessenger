require("tests.helpers.fake_ui")
local SeenGuild = require("WhisperMessenger.Model.SeenGuild")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")

local STUBBED = {
  "UnitIsPlayer",
  "UnitGUID",
  "UnitLevel",
  "UnitFullName",
  "GetGuildInfo",
  "issecretvalue",
  "_wmSuspended",
  "UNKNOWNOBJECT",
}

local function fire(event, ...)
  local frame = SeenLevelEvents._frame
  frame:GetScript("OnEvent")(frame, event, ...)
end

local function stubUnits(units)
  rawset(_G, "UnitIsPlayer", function(unit)
    return units[unit] ~= nil
  end)
  rawset(_G, "UnitGUID", function(unit)
    return units[unit] and units[unit].guid
  end)
  rawset(_G, "UnitLevel", function(unit)
    return units[unit] and units[unit].level
  end)
  rawset(_G, "UnitFullName", function(unit)
    local u = units[unit]
    if u == nil then
      return nil
    end
    return u.name, u.realm
  end)
end

local function makeRuntime(results)
  local list = results or {}
  return {
    localProfileId = "me",
    store = { conversations = {} },
    scheduleIncomingRefresh = function() end,
    friendListApi = {
      GetNumWhoResults = function()
        return #list
      end,
      GetWhoInfo = function(i)
        return list[i]
      end,
    },
  }
end

return function()
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = rawget(_G, name)
  end
  local realOnWhoListUpdate = WhoLookup.OnWhoListUpdate
  local function reset()
    for _, name in ipairs(STUBBED) do
      rawset(_G, name, nil)
    end
    SeenLevelEvents._reset()
    SeenLevel._reset()
    SeenGuild._reset()
    rawset(WhoLookup, "OnWhoListUpdate", function() end)
  end

  local function startWho(results)
    reset()
    SeenLevelEvents.Init(makeRuntime(results))
    SeenLevelEvents.SetEnabled(true)
    SeenLevelEvents.OpenWhoWindow()
  end

  local function startUnit(guildInfo)
    reset()
    stubUnits({ target = { guid = "Player-1-A", level = 60, name = "Arthas", realm = "Area52" } })
    rawset(_G, "GetGuildInfo", guildInfo)
    SeenLevelEvents.Init(makeRuntime())
    SeenLevelEvents.SetEnabled(true)
  end

  -- test_who_row_records_guild
  do
    startWho({ { fullName = "Arthas-Area52", level = 60, fullGuildName = "Horde Inc", area = "Orgrimmar" } })
    fire("WHO_LIST_UPDATE")
    assert(SeenGuild.Get("Arthas-Area52") == "Horde Inc", "who row guild should be recorded")
  end

  -- test_who_row_empty_guild_records_empty
  do
    startWho({ { fullName = "Arthas-Area52", level = 60, fullGuildName = "", area = "Orgrimmar" } })
    fire("WHO_LIST_UPDATE")
    assert(SeenGuild.Get("Arthas-Area52") == "", "who row without guild should record empty string")
  end

  -- test_who_system_line_for_other_row_ignored
  do
    startWho({ { fullName = "Arthas-Area52", level = 60, fullGuildName = "Horde Inc", area = "Orgrimmar" } })
    fire("CHAT_MSG_SYSTEM", "|Hplayer:Bob|h[Bob]|h: Level 70 Human Mage - Stormwind")
    assert(SeenGuild.Get("Arthas-Area52") == nil, "a line for another player must not record this row")
  end

  -- test_target_records_guild
  do
    startUnit(function()
      return "Horde Inc"
    end)
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenGuild.Get("Arthas-Area52") == "Horde Inc", "target guild should be recorded")
  end

  -- test_unit_nil_guild_not_recorded
  do
    startUnit(function()
      return nil
    end)
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenGuild.Get("Arthas-Area52") == nil, "nil guild means not loaded yet, not guildless")
  end

  -- test_unit_empty_guild_not_recorded
  do
    startUnit(function()
      return ""
    end)
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenGuild.Get("Arthas-Area52") == nil, "an empty unit guild is not recorded")
  end

  -- test_unit_guild_throw_keeps_level
  do
    startUnit(function()
      error("guild read failed")
    end)
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenLevel.Get("Player-1-A") == 60, "a throwing guild read must not drop the level")
    assert(SeenGuild.Get("Arthas-Area52") == nil, "a throwing guild read records nothing")
  end

  -- test_unit_secret_guild_not_recorded
  do
    startUnit(function()
      return "Horde Inc"
    end)
    rawset(_G, "issecretvalue", function()
      return true
    end)
    fire("PLAYER_TARGET_CHANGED")
    assert(SeenGuild.Get("Arthas-Area52") == nil, "secret guild must not be stored")
    assert(SeenLevel.Get("Player-1-A") == 60, "secret guild must not drop the level")
  end

  for _, name in ipairs(STUBBED) do
    rawset(_G, name, saved[name])
  end
  WhoLookup.OnWhoListUpdate = realOnWhoListUpdate
  SeenLevelEvents._reset()
  SeenLevel._reset()
  SeenGuild._reset()
end
