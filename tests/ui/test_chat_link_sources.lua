-- Blizzard click handlers that only insert a chat link while one of Blizzard's
-- own chat boxes is open. ChatLinkSources post-hooks them and hands the link
-- the handler would have built to `insert`; it never assigns a Blizzard slot.
local ChatLinkSourcesEnv = require("tests.helpers.chat_link_sources_env")

local MODULE = "WhisperMessenger.UI.Composer.ChatLinkSources"
local GLOBALS = {
  "QuestLogTitleButton_OnClick",
  "QuestLogListScrollFrame",
  "FauxScrollFrame_GetOffset",
  "GetQuestIDFromLogIndex",
  "GetQuestLink",
  "AchievementButton_OnClick",
  "GetAchievementLink",
  "WatchFrameLinkButtonTemplate_OnClick",
  "WatchFrameItem_OnClick",
  "GetQuestIndexForWatch",
  "GetQuestLogSpecialItemInfo",
  "ScorePlayer_OnClick",
  "ScorePlayer_OnMouseUp",
}

local function withEnv(setup, body)
  ChatLinkSourcesEnv.With(MODULE, GLOBALS, function(env)
    rawset(_G, "QuestLogTitleButton_OnClick", function(_button, _mouseButton) end)
    setup(env)
  end, body)
end

local function questButton(id, text, isHeader)
  return {
    isHeader = isHeader,
    GetID = function()
      return id
    end,
    GetText = function()
      return text
    end,
  }
end

local function installWrathQuestApi()
  rawset(_G, "QuestLogListScrollFrame", {})
  rawset(_G, "FauxScrollFrame_GetOffset", function(_scrollFrame)
    return 10
  end)
  rawset(_G, "GetQuestIDFromLogIndex", function(index)
    return index == 12 and 471 or nil
  end)
  rawset(_G, "GetQuestLink", function(questID)
    return "|Hquest:" .. questID .. ":10|h[Apprentice's Duties]|h"
  end)
end

local function noSetup() end

return function()
  -- test_vanilla_quest_log_click_inserts_trimmed_title
  withEnv(noSetup, function(env)
    _G.QuestLogTitleButton_OnClick(questButton(2, "  [Apprentice's Duties (471)]"), "LeftButton")
    assert(env.inserts[1] == "[Apprentice's Duties (471)]", "expected the trimmed title, got: " .. tostring(env.inserts[1]))
  end)

  -- test_wrath_quest_log_click_inserts_quest_link
  withEnv(installWrathQuestApi, function(env)
    _G.QuestLogTitleButton_OnClick(questButton(2, "Apprentice's Duties"), "LeftButton")
    assert(env.inserts[1] == "|Hquest:471:10|h[Apprentice's Duties]|h", "expected the quest link, got: " .. tostring(env.inserts[1]))
  end)

  -- test_quest_log_skips_headers_and_plain_clicks
  withEnv(noSetup, function(env)
    _G.QuestLogTitleButton_OnClick(questButton(1, "Elwynn Forest", true), "LeftButton")
    env.chatLink = false
    _G.QuestLogTitleButton_OnClick(questButton(2, "Apprentice's Duties"), "LeftButton")
    assert(#env.inserts == 0, "headers and non-link clicks must not insert, got " .. #env.inserts)
  end)

  -- test_missing_handlers_register_nothing
  withEnv(function()
    rawset(_G, "QuestLogTitleButton_OnClick", nil)
  end, function(env)
    assert(_G.QuestLogTitleButton_OnClick == nil, "a missing handler must stay missing")
    assert(_G.WatchFrameItem_OnClick == nil, "a missing handler must stay missing")
    assert(#env.inserts == 0, "nothing inserts without handlers")
  end)

  -- test_register_also_hooks_blizzard_addon_sources
  withEnv(function()
    rawset(_G, "AchievementButton_OnClick", function(_button, _second, _down, _fourth) end)
    rawset(_G, "GetAchievementLink", function(id)
      return "|Hachievement:" .. id .. "|h[Level 10]|h"
    end)
  end, function(env)
    _G.AchievementButton_OnClick({ id = 6 }, "LeftButton", false)
    assert(env.inserts[1] == "|Hachievement:6|h[Level 10]|h", "expected the achievement link, got: " .. tostring(env.inserts[1]))
  end)

  -- test_watch_frame_quest_line_inserts_quest_link
  withEnv(function()
    installWrathQuestApi()
    rawset(_G, "WatchFrameLinkButtonTemplate_OnClick", function(_self, _button, _pushed) end)
    rawset(_G, "GetQuestIndexForWatch", function(watchIndex)
      return watchIndex + 9
    end)
  end, function(env)
    _G.WatchFrameLinkButtonTemplate_OnClick({ type = "QUEST", index = 3 }, "LeftButton", false)
    assert(env.inserts[1] == "|Hquest:471:10|h[Apprentice's Duties]|h", "expected the tracked quest's link, got: " .. tostring(env.inserts[1]))
  end)

  -- test_watch_frame_achievement_line_inserts_achievement_link
  withEnv(function()
    rawset(_G, "WatchFrameLinkButtonTemplate_OnClick", function(_self, _button, _pushed) end)
    rawset(_G, "GetAchievementLink", function(id)
      return "|Hachievement:" .. id .. "|h[Level 10]|h"
    end)
  end, function(env)
    _G.WatchFrameLinkButtonTemplate_OnClick({ type = "ACHIEVEMENT", index = 6 }, "LeftButton", false)
    env.chatLink = false
    _G.WatchFrameLinkButtonTemplate_OnClick({ type = "ACHIEVEMENT", index = 7 }, "LeftButton", false)
    assert(
      #env.inserts == 1 and env.inserts[1] == "|Hachievement:6|h[Level 10]|h",
      "expected one achievement link, got: " .. tostring(env.inserts[1])
    )
  end)

  -- test_watch_frame_item_inserts_item_link
  withEnv(function()
    rawset(_G, "WatchFrameItem_OnClick", function(_self, _button, _down) end)
    rawset(_G, "GetQuestLogSpecialItemInfo", function(questIndex)
      return questIndex == 4 and "|Hitem:33278|h[Burning Torch]|h" or nil, "item", 1
    end)
  end, function(env)
    _G.WatchFrameItem_OnClick({
      GetID = function()
        return 4
      end,
    }, "LeftButton", false)
    assert(env.inserts[1] == "|Hitem:33278|h[Burning Torch]|h", "expected the quest item link, got: " .. tostring(env.inserts[1]))
  end)

  -- test_watch_frame_item_plain_click_inserts_nothing
  withEnv(function()
    rawset(_G, "WatchFrameItem_OnClick", function(_self, _button, _down) end)
    rawset(_G, "GetQuestLogSpecialItemInfo", function(_questIndex)
      return "|Hitem:33278|h[Burning Torch]|h", "item", 1
    end)
  end, function(env)
    env.chatLink = false
    _G.WatchFrameItem_OnClick({
      GetID = function()
        return 4
      end,
    }, "LeftButton", false)
    assert(#env.inserts == 0, "a plain click must not insert, got " .. #env.inserts)
  end)

  -- test_scoreboard_left_click_inserts_player_name
  -- (Vanilla binds ScorePlayer_OnClick, TBC and later ScorePlayer_OnMouseUp)
  withEnv(function()
    rawset(_G, "ScorePlayer_OnClick", function(_self, _mouseButton) end)
    rawset(_G, "ScorePlayer_OnMouseUp", function(_self, _mouseButton) end)
  end, function(env)
    local row = {
      text = {
        GetText = function()
          return "Ara"
        end,
      },
    }
    _G.ScorePlayer_OnClick(row, "LeftButton")
    _G.ScorePlayer_OnMouseUp(row, "LeftButton")
    _G.ScorePlayer_OnMouseUp(row, "RightButton")
    assert(#env.inserts == 2 and env.inserts[2] == "Ara", "expected the name from both handlers, got " .. #env.inserts)
  end)

  -- test_scoreboard_plain_click_inserts_nothing
  withEnv(function()
    rawset(_G, "ScorePlayer_OnClick", function(_self, _mouseButton) end)
    rawset(_G, "ScorePlayer_OnMouseUp", function(_self, _mouseButton) end)
  end, function(env)
    env.chatLink = false
    local row = {
      text = {
        GetText = function()
          return "Ara"
        end,
      },
    }
    _G.ScorePlayer_OnClick(row, "LeftButton")
    _G.ScorePlayer_OnMouseUp(row, "LeftButton")
    assert(#env.inserts == 0, "a plain click must not insert, got " .. #env.inserts)
  end)

  -- test_registering_every_hook_assigns_no_global
  -- (the env fails on any global assignment; every hook target exists here)
  withEnv(function()
    for _, name in ipairs({
      "WatchFrameLinkButtonTemplate_OnClick",
      "WatchFrameItem_OnClick",
      "ScorePlayer_OnClick",
      "ScorePlayer_OnMouseUp",
      "AchievementButton_OnClick",
    }) do
      rawset(_G, name, function() end)
    end
  end, function(env)
    assert(#env.writes == 0, "Register assigned " .. table.concat(env.writes, ", "))
  end)
end
