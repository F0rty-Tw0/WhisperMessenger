require("tests.helpers.fake_ui")
local Identity = require("WhisperMessenger.Model.Identity")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local SeenZone = require("WhisperMessenger.Model.SeenZone")
local SeenGuild = require("WhisperMessenger.Model.SeenGuild")
local RaceTags = require("WhisperMessenger.Model.Identity.RaceTags")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")

local STUBBED = { "issecretvalue", "_wmSuspended", "C_CreatureInfo" }

local RACES = {
  [1] = { raceName = "Human", clientFileString = "Human" },
  [5] = { raceName = "Undead", clientFileString = "Scourge" },
  [24] = { raceName = "Pandaren", clientFileString = "Pandaren" },
}

local function fire(event, ...)
  local frame = SeenLevelEvents._frame
  frame:GetScript("OnEvent")(frame, event, ...)
end

local function makeRuntime(results)
  local runtime = { localProfileId = "me", store = { conversations = {} }, refreshed = {} }
  runtime.scheduleIncomingRefresh = function(key)
    runtime.refreshed[#runtime.refreshed + 1] = key
  end
  runtime.friendListApi = {
    GetNumWhoResults = function()
      return #results
    end,
    GetWhoInfo = function(i)
      return results[i]
    end,
  }
  return runtime
end

local function saveChat(runtime, name, fields)
  local key = Identity.BuildConversationKey(runtime.localProfileId, "WOW::" .. SeenLevel.NameKey(name))
  local conversation = { conversationKey = key, channel = "WOW" }
  for field, value in pairs(fields or {}) do
    conversation[field] = value
  end
  runtime.store.conversations[key] = conversation
  return conversation, key
end

-- No area and a known level: only the identity write-back can schedule a refresh.
local function row(fields)
  local info = { fullName = "Arthas", level = 60, classStr = "Mage", filename = "MAGE", raceStr = "Undead" }
  for field, value in pairs(fields or {}) do
    info[field] = value
  end
  return info
end

return function()
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = rawget(_G, name)
  end
  local realOnWhoListUpdate = WhoLookup.OnWhoListUpdate

  local function start(results)
    for _, name in ipairs(STUBBED) do
      rawset(_G, name, nil)
    end
    rawset(_G, "C_CreatureInfo", {
      GetRaceInfo = function(id)
        return RACES[id]
      end,
    })
    SeenLevelEvents._reset()
    SeenLevel._reset()
    SeenZone._reset()
    SeenGuild._reset()
    RaceTags._reset()
    rawset(WhoLookup, "OnWhoListUpdate", function() end)
    local runtime = makeRuntime(results)
    SeenLevelEvents.Init(runtime)
    SeenLevelEvents.SetEnabled(true)
    return runtime
  end

  -- test_who_row_writes_class_race_and_faction
  do
    local runtime = start({ row() })
    local chat = saveChat(runtime, "Arthas")
    fire("WHO_LIST_UPDATE")
    assert(chat.className == "Mage", "className should come from the row")
    assert(chat.classTag == "MAGE", "classTag should come from the row's filename")
    assert(chat.raceName == "Undead", "raceName should come from the row")
    assert(chat.raceTag == "Scourge", "raceTag should be looked up from the race name")
    assert(chat.factionName == "Horde", "faction should follow the race tag")
  end

  -- test_who_row_overwrites_stored_class
  do
    local runtime = start({ row() })
    local chat = saveChat(runtime, "Arthas", { className = "Priest", classTag = "PRIEST" })
    fire("WHO_LIST_UPDATE")
    assert(chat.className == "Mage" and chat.classTag == "MAGE", "the /who answer is the freshest source")
  end

  -- test_unmapped_race_shows_race_without_faction
  do
    local runtime = start({ row({ raceStr = "Untote" }) })
    local chat = saveChat(runtime, "Arthas")
    fire("WHO_LIST_UPDATE")
    assert(chat.raceName == "Untote", "an unmapped race still shows")
    assert(chat.raceTag == nil and chat.factionName == nil, "an unmapped race gets no tag or faction")
  end

  -- test_changed_unmapped_race_clears_old_tag_and_faction
  do
    local runtime = start({ row({ raceStr = "Untote" }) })
    local chat = saveChat(runtime, "Arthas", { raceName = "Human", raceTag = "Human", factionName = "Alliance" })
    fire("WHO_LIST_UPDATE")
    assert(chat.raceName == "Untote", "the new race shows")
    assert(chat.raceTag == nil, "the old race tag must not stay with a new race")
    assert(chat.factionName == nil, "the old faction must not stay with a new race")
  end

  -- test_guid_chat_unmapped_race_keeps_tag_and_faction
  -- Gendered locales: /who may spell the race another way than the GUID did.
  do
    local runtime = start({ row({ raceStr = "Morte-vivante" }) })
    local chat = saveChat(runtime, "Arthas", {
      guid = "Player-1-A",
      characterLevel = 60,
      className = "Mage",
      classTag = "MAGE",
      raceName = "Mort-vivant",
      raceTag = "Scourge",
      factionName = "Horde",
    })
    fire("WHO_LIST_UPDATE")
    assert(chat.raceName == "Morte-vivante", "the /who race still shows")
    assert(#runtime.refreshed == 1, "only the new race name refreshes the chat")
    assert(chat.raceTag == "Scourge", "a guid chat keeps its race tag")
    assert(chat.factionName == "Horde", "a guid chat keeps its faction")
  end

  -- test_same_unmapped_race_keeps_tag_and_faction
  do
    local runtime = start({ row({ raceStr = "Untote" }) })
    local chat = saveChat(runtime, "Arthas", { raceName = "Untote", raceTag = "Scourge", factionName = "Horde" })
    fire("WHO_LIST_UPDATE")
    assert(chat.raceTag == "Scourge" and chat.factionName == "Horde", "a failed lookup leaves stored tag and faction")
  end

  -- test_neutral_race_leaves_faction_untouched
  do
    local runtime = start({ row({ raceStr = "Pandaren" }) })
    local chat = saveChat(runtime, "Arthas", { factionName = "Alliance" })
    fire("WHO_LIST_UPDATE")
    assert(chat.raceTag == "Pandaren", "a neutral race still maps to its tag")
    assert(chat.factionName == "Alliance", "a neutral race leaves the faction untouched")
  end

  -- test_secret_field_skipped_others_written
  do
    local runtime = start({ row({ classStr = "SECRET" }) })
    local chat = saveChat(runtime, "Arthas", { className = "Priest" })
    rawset(_G, "issecretvalue", function(value)
      return value == "SECRET"
    end)
    fire("WHO_LIST_UPDATE")
    assert(chat.className == "Priest", "a secret class must not be stored")
    assert(chat.classTag == "MAGE", "a secret class must not block the class tag")
    assert(chat.raceName == "Undead", "a secret class must not block the race")
  end

  -- test_empty_and_missing_fields_skipped
  do
    local runtime = start({ row({ classStr = "", filename = false, raceStr = "" }) })
    local chat = saveChat(runtime, "Arthas", { className = "Priest", classTag = "PRIEST", raceName = "Human" })
    fire("WHO_LIST_UPDATE")
    assert(chat.className == "Priest", "an empty class must not be stored")
    assert(chat.classTag == "PRIEST", "a missing class tag must not be stored")
    assert(chat.raceName == "Human", "an empty race must not be stored")
  end

  -- test_no_chat_writes_nothing
  do
    local runtime = start({ row({ fullName = "Stranger" }) })
    local chat = saveChat(runtime, "Arthas")
    fire("WHO_LIST_UPDATE")
    assert(chat.className == nil, "a row for another name must not touch this chat")
    assert(#runtime.refreshed == 0, "no chat means no refresh")
  end

  -- test_bn_chat_not_written
  do
    local runtime = start({ row() })
    local chat = saveChat(runtime, "Arthas", { channel = "BN" })
    fire("WHO_LIST_UPDATE")
    assert(chat.className == nil, "a Battle.net chat is not a /who match")
  end

  -- test_guid_chat_written_too
  do
    local runtime = start({ row() })
    local chat = saveChat(runtime, "Arthas", { guid = "Player-1-A" })
    fire("WHO_LIST_UPDATE")
    assert(chat.className == "Mage", "a chat with a guid also takes the /who class")
  end

  -- test_refresh_only_when_a_field_changed
  do
    local runtime = start({ row() })
    local _, key = saveChat(runtime, "Arthas", { characterLevel = 60 })
    fire("WHO_LIST_UPDATE")
    assert(#runtime.refreshed == 1 and runtime.refreshed[1] == key, "a changed field should refresh the chat")
    fire("WHO_LIST_UPDATE")
    assert(#runtime.refreshed == 1, "the same answer again must not refresh")
  end

  -- test_system_line_for_other_player_writes_nothing
  do
    local runtime = start({ row({ area = "Orgrimmar" }) })
    local chat = saveChat(runtime, "Arthas")
    fire("CHAT_MSG_SYSTEM", "|Hplayer:Bob|h[Bob]|h: Level 70 Human Mage - Stormwind")
    assert(chat.className == nil and chat.raceName == nil, "a line for another player must not write this row")
  end

  -- test_system_line_for_this_row_writes
  do
    local runtime = start({ row({ area = "Orgrimmar" }) })
    local chat = saveChat(runtime, "Arthas")
    fire("CHAT_MSG_SYSTEM", "|Hplayer:Arthas|h[Arthas]|h: Level 60 Undead Mage - Orgrimmar")
    assert(chat.className == "Mage", "the row's own system line should write it")
  end

  for _, name in ipairs(STUBBED) do
    rawset(_G, name, saved[name])
  end
  WhoLookup.OnWhoListUpdate = realOnWhoListUpdate
  SeenLevelEvents._reset()
  SeenLevel._reset()
  SeenZone._reset()
  SeenGuild._reset()
  RaceTags._reset()
end
