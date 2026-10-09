local FakeChatLines = require("tests.helpers.fake_chat_lines")
local ReplayRuntime = require("tests.helpers.lockdown_replay_runtime")
local LockdownReplay = require("WhisperMessenger.Core.Bootstrap.LockdownReplay")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

local SECRET = FakeChatLines.SECRET
local KEY = "wow::WOW::arthas-area52"
local FRIEND_NAME = "|Ks1|k"

local function friendApi()
  local friend = { bnetAccountID = 12, battleTag = "Friend#1234", accountName = FRIEND_NAME, isOnline = true }
  return {
    GetNumFriends = function()
      return 1
    end,
    GetFriendAccountInfo = function(index)
      return index == 1 and friend or nil
    end,
    GetAccountInfoByID = function(id)
      return id == 12 and friend or nil
    end,
  }
end

-- Holds one line, kicks the replay and fires the ticker `fires` times.
local function replayOne(eventName, line, fires, setup)
  local restore = FakeChatLines.Install({ [7] = line })
  local runtime = ReplayRuntime.New()
  if setup then
    setup(runtime)
  end
  ReplayRuntime.Hold(runtime, eventName, 7)
  LockdownReplay.Kick(runtime)
  for _ = 1, fires or 1 do
    FakeChatLines.Fire()
  end
  return runtime, restore
end

local function summary(runtime)
  return runtime.lockdownReplay.lastSummary
end

return function()
  -- test_inform_line_files_as_outgoing_in_recipient_conversation

  do
    local runtime, restore = replayOne("CHAT_MSG_WHISPER_INFORM", { text = "my reply", name = "Arthas-Area52", guid = "Player-1-ABC" })
    local conversation = runtime.store.conversations[KEY]
    assert(conversation ~= nil and conversation.messages[1].direction == "out", "held inform must file as outgoing for the recipient")
    assert(summary(runtime).filed == 0 and summary(runtime).lost == 0, "outgoing lines are not counted")
    restore()
  end

  -- test_bnet_line_resolves_through_account_name

  do
    local runtime, restore = replayOne("CHAT_MSG_BN_WHISPER", { text = "hi", name = FRIEND_NAME }, 1, function(rt)
      rt.bnetApi = friendApi()
    end)
    local stored
    for key, conversation in pairs(runtime.store.conversations) do
      if string.find(key, "bnet::", 1, true) == 1 then
        stored = conversation
      end
    end
    assert(stored ~= nil and stored.bnetAccountID == 12, "held BNet whisper must file under the friend's account")
    assert(summary(runtime).filed == 1, "BNet whisper counted as filed")
    restore()
  end

  -- test_bnet_non_friend_is_lost

  do
    local runtime, restore = replayOne("CHAT_MSG_BN_WHISPER", { text = "hi", name = "|Ks9|k" }, 1, function(rt)
      rt.bnetApi = friendApi()
    end)
    assert(summary(runtime).lost == 1 and summary(runtime).filed == 0, "an unknown BNet sender must count as lost")
    restore()
  end

  -- test_secret_text_retries_then_lost_after_40_tries

  do
    local runtime, restore = replayOne("CHAT_MSG_WHISPER", { text = SECRET, name = "Arthas-Area52", guid = "Player-1-ABC" }, 39)
    assert(runtime.lockdownReplay.lastSummary == nil and LockdownReplay.IsPending(runtime), "line must stay held after 39 tries")
    FakeChatLines.Fire()
    assert(summary(runtime) ~= nil and summary(runtime).lost == 1, "line must be lost on the 40th try")
    restore()
  end

  -- test_secret_guid_retries

  do
    local runtime, restore = replayOne("CHAT_MSG_WHISPER", { text = "hi", name = "Arthas-Area52", guid = SECRET })
    assert(runtime.lockdownReplay.lastSummary == nil, "a secret GUID must not file")
    assert(runtime.lockdownReplay.drained[1].tries == 1, "a secret GUID must spend a try")
    restore()
  end

  -- test_nil_guid_files_fine

  do
    local runtime, restore = replayOne("CHAT_MSG_WHISPER", { text = "hi", name = "Arthas-Area52" })
    assert(summary(runtime).filed == 1, "a missing GUID must still file")
    restore()
  end

  -- test_invalid_line_lost_at_once

  do
    local runtime, restore = replayOne("CHAT_MSG_WHISPER", { text = "hi", name = "Arthas-Area52", valid = false })
    assert(summary(runtime).lost == 1, "an invalid line must be lost on the first try")
    restore()
  end

  -- test_valid_line_check_error_still_files_readable_line

  do
    local runtime, restore = replayOne("CHAT_MSG_WHISPER", { text = "hi", name = "Arthas-Area52" }, 1, function()
      _G.C_ChatInfo.IsValidChatLine = function()
        error("line check failed")
      end
    end)
    assert(summary(runtime).filed == 1, "a failing line check must not lose a readable line")
    restore()
  end

  -- test_converted_reaction_not_counted

  do
    local savedRoute = EventBridge.RouteReplayedEvent
    rawset(EventBridge, "RouteReplayedEvent", function()
      return { conversationKey = KEY }, { reactionControl = true }
    end)
    local runtime, restore = replayOne("CHAT_MSG_WHISPER", { text = "hi", name = "Arthas-Area52" })
    rawset(EventBridge, "RouteReplayedEvent", savedRoute)
    assert(summary(runtime).filed == 0, "a whisper converted to a reaction is not counted")
    restore()
  end

  -- test_sync_degraded_counted

  do
    local savedRoute = EventBridge.RouteReplayedEvent
    local routedArgs
    rawset(EventBridge, "RouteReplayedEvent", function(...)
      routedArgs = { n = select("#", ...), ... }
      return { conversationKey = KEY }, { reactionDegraded = true }
    end)
    local runtime, restore = replayOne("CHAT_MSG_WHISPER", { text = "hi", name = "Arthas-Area52", guid = "Player-1-ABC" })
    rawset(EventBridge, "RouteReplayedEvent", savedRoute)
    assert(summary(runtime).filed == 1, "a degraded reaction whisper is counted")
    -- runtime, refreshWindow, event, receivedAt, then live args: 1 text, 2 name, 11 lineID, 12 guid.
    assert(routedArgs[3] == "CHAT_MSG_WHISPER" and routedArgs[4] == 500, "route gets the event and its held time")
    assert(routedArgs[5] == "hi" and routedArgs[6] == "Arthas-Area52", "route gets text and name in args 1-2")
    assert(routedArgs[15] == 7 and routedArgs[16] == "Player-1-ABC", "route gets line ID and GUID in args 11-12")
    restore()
  end

  -- test_route_error_loses_that_line_files_the_rest_once_and_finishes

  do
    local function line(text)
      return { text = text, name = "Arthas-Area52", guid = "Player-1-ABC" }
    end
    local restore = FakeChatLines.Install({ [7] = line("one"), [8] = line("two"), [9] = line("three") })
    local runtime = ReplayRuntime.New()
    for lineID = 7, 9 do
      ReplayRuntime.Hold(runtime, "CHAT_MSG_WHISPER", lineID)
    end
    local savedRoute = EventBridge.RouteReplayedEvent
    local calls = 0
    rawset(EventBridge, "RouteReplayedEvent", function(...)
      calls = calls + 1
      if calls == 2 then
        error("route failed")
      end
      return savedRoute(...)
    end)
    LockdownReplay.Kick(runtime)
    for _ = 1, 3 do
      pcall(FakeChatLines.Fire)
    end
    rawset(EventBridge, "RouteReplayedEvent", savedRoute)
    local stored = {}
    for _, message in ipairs(runtime.store.conversations[KEY].messages) do
      stored[message.text] = (stored[message.text] or 0) + 1
    end
    assert(stored.one == 1, "the line routed before the error must be stored once, got " .. tostring(stored.one))
    assert(stored.three == 1, "the line after the error must still file, got " .. tostring(stored.three))
    assert(summary(runtime) ~= nil and runtime.lockdownReplay.ticker == nil, "the batch must still finish")
    assert(summary(runtime).lost == 1, "the line that errored counts as lost, got " .. tostring(summary(runtime).lost))
    restore()
  end
end
