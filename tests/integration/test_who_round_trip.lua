require("tests.helpers.fake_ui")
local Identity = require("WhisperMessenger.Model.Identity")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")
local Env = require("tests.helpers.who_lookup_env")

-- Real WhoLookup + SeenLevelEvents + SeenLevel wired the way Bootstrap does;
-- only the WoW APIs are faked: a quiet /who for a saved stranger chat goes
-- out, its result lands on the chat, and FriendsFrame gets its event back.

local WHO_EVENTS = { "WHO_LIST_UPDATE", "CHAT_MSG_SYSTEM" }

local function isRegistered(event)
  return SeenLevelEvents._frame:IsEventRegistered(event)
end

local function assertWhoEvents(expected, label)
  for _, event in ipairs(WHO_EVENTS) do
    assert(isRegistered(event) == expected, event .. " " .. label)
  end
end

local function fire(event, ...)
  local frame = SeenLevelEvents._frame
  frame:GetScript("OnEvent")(frame, event, ...)
end

local function wire(env, results)
  local runtime = env.runtime
  runtime.localProfileId = "me"
  runtime.refreshed = {}
  runtime.scheduleIncomingRefresh = function(key)
    runtime.refreshed[#runtime.refreshed + 1] = key
  end
  env.api.GetNumWhoResults = function()
    return #results
  end
  env.api.GetWhoInfo = function(i)
    return results[i]
  end
  runtime.friendListApi = env.api
  runtime.seenLevelEvents = SeenLevelEvents
  SeenLevelEvents._reset()
  SeenLevelEvents.Init(runtime)
  SeenLevelEvents.SetEnabled(true)
  WhoLookup.Init(runtime)
  local key = Identity.BuildConversationKey("me", "WOW::firstmoon")
  return key, Env.AddStranger(env, key, "Firstmoon")
end

local function test_who_result_reaches_saved_chat_and_frees_friends_frame()
  Env.Case("round trip", { whoToUi = false }, function(env)
    local key, conversation = wire(env, { { fullName = "Firstmoon", level = 75 } })
    assert(WhoLookup.TryFor(env.runtime, key) == true, "quiet /who sent")
    assert(env.sent[1] == 'n-"Firstmoon"', tostring(env.sent[1]))
    assertWhoEvents(true, "should be registered while the query is out")
    assert(env.friendsRegistered == false, "FriendsFrame held back")
    fire("WHO_LIST_UPDATE")
    assert(conversation.characterLevel == 75, "saved chat should get level 75, got " .. tostring(conversation.characterLevel))
    assert(env.runtime.refreshed[1] == key, "refresh scheduled for the chat")
    assert(env.friendsRegistered == false, "re-register waits a frame")
    Env.RunAfters(env)
    assert(env.friendsRegistered == true, "FriendsFrame gets WHO_LIST_UPDATE back")
    assert(env.whoToUi[#env.whoToUi] == false, "SetWhoToUi restored")
    env.clock = env.clock + WhoLookup.WINDOW_SECONDS
    Env.FireDueTimers(env)
    assertWhoEvents(false, "should be unregistered after the window")
    assert(isRegistered("PLAYER_TARGET_CHANGED"), "unit events stay")
  end)
end

local function test_option_off_mid_query_still_cleans_up()
  Env.Case("option off mid-query", { whoToUi = false }, function(env)
    local key = wire(env, { { fullName = "Firstmoon", level = 75 } })
    WhoLookup.TryFor(env.runtime, key)
    DisplayName.Configure({ showPlayerLevels = false })
    SeenLevelEvents.SetEnabled(false)
    assertWhoEvents(false, "should be unregistered once the option is off")
    env.clock = env.clock + WhoLookup.WINDOW_SECONDS
    Env.FireDueTimers(env)
    assert(env.friendsRegistered == true, "FriendsFrame re-registered at the window end")
    assert(env.whoToUi[#env.whoToUi] == false, "SetWhoToUi restored")
  end)
end

return function()
  test_who_result_reaches_saved_chat_and_frees_friends_frame()
  test_option_off_mid_query_still_cleans_up()
  SeenLevelEvents._reset()
end
