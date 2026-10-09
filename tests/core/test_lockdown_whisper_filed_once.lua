-- Every whisper reaches both the live handler and the lockdown catcher. Each
-- secret-arg mix must end up stored exactly once across the two paths.
local FakeChatLines = require("tests.helpers.fake_chat_lines")
local ReplayRuntime = require("tests.helpers.lockdown_replay_runtime")
local LockdownReplay = require("WhisperMessenger.Core.Bootstrap.LockdownReplay")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local Router = require("WhisperMessenger.Core.EventRouter")

-- Lua 5.1 (CI) has no `table.unpack`; Lua 5.3+ has no global `unpack`.
local unpackArgs = table.unpack or unpack

local SECRET = FakeChatLines.SECRET
local LINE_ID = 7
local ARG_COUNT = 13
local FRIEND_NAME = "|Ks1|k"
local CHARACTER_GUID = "Player-1-ABC"
local BNET_ACCOUNT_ID = 12

local function friendApi(gameAccountInfo)
  local friend = {
    bnetAccountID = BNET_ACCOUNT_ID,
    battleTag = "Friend#1234",
    accountName = FRIEND_NAME,
    isOnline = true,
    gameAccountInfo = gameAccountInfo,
  }
  return {
    GetNumFriends = function()
      return 1
    end,
    GetFriendAccountInfo = function(index)
      return index == 1 and friend or nil
    end,
    GetAccountInfoByID = function(id)
      return id == BNET_ACCOUNT_ID and friend or nil
    end,
  }
end

local function eventArgs(isBNet, secretArgs)
  local args = { "hi", "Arthas-Area52" }
  args[11] = LINE_ID
  args[12] = CHARACTER_GUID
  if isBNet then
    args[2] = FRIEND_NAME
    args[13] = BNET_ACCOUNT_ID
  end
  for _, index in ipairs(secretArgs) do
    args[index] = SECRET
  end
  return args
end

local function storedCount(runtime)
  local count = 0
  for _, conversation in pairs(runtime.store.conversations) do
    count = count + #conversation.messages
  end
  return count
end

-- Delivers one whisper to the live handler and the catcher during a lock,
-- lifts the lock, runs the replay and returns how many messages were stored.
local function deliver(eventName, secretArgs, gameAccountInfo)
  local isBNet = eventName == "CHAT_MSG_BN_WHISPER"
  local readBack = { text = "hi", name = isBNet and FRIEND_NAME or "Arthas-Area52", guid = CHARACTER_GUID }
  local restore = FakeChatLines.Install({ [LINE_ID] = readBack })
  local savedDetector = Router._isSecretString
  Router._isSecretString = _G.issecretvalue
  local runtime = ReplayRuntime.New()
  runtime.bnetApi = friendApi(gameAccountInfo)
  local args = eventArgs(isBNet, secretArgs)
  FakeChatLines.locked = true
  EventBridge.RouteLiveEvent(runtime, runtime.refreshWindow, eventName, unpackArgs(args, 1, ARG_COUNT))
  runtime.lockdownCatcher.handle(eventName, unpackArgs(args, 1, ARG_COUNT))
  FakeChatLines.locked = false
  LockdownReplay.Kick(runtime)
  ReplayRuntime.FireUntilDone(runtime)
  local count = storedCount(runtime)
  Router._isSecretString = savedDetector
  restore()
  return count
end

local function assertFiledOnce(label, eventName, secretArgs, gameAccountInfo)
  local count = deliver(eventName, secretArgs, gameAccountInfo)
  assert(count == 1, label .. " must be filed exactly once, got " .. count)
end

return function()
  -- test_character_whisper_secret_text_filed_once
  do
    assertFiledOnce("character whisper with secret text", "CHAT_MSG_WHISPER", { 1 })
  end

  -- test_character_whisper_secret_sender_filed_once
  do
    assertFiledOnce("character whisper with secret sender", "CHAT_MSG_WHISPER", { 2 })
  end

  -- test_character_whisper_secret_guid_filed_once
  do
    assertFiledOnce("character whisper with secret GUID", "CHAT_MSG_WHISPER", { 12 })
  end

  -- test_bnet_whisper_secret_text_filed_once
  do
    assertFiledOnce("BNet whisper with secret text", "CHAT_MSG_BN_WHISPER", { 1 })
  end

  -- test_bnet_whisper_secret_sender_filed_once
  do
    assertFiledOnce("BNet whisper with secret sender", "CHAT_MSG_BN_WHISPER", { 2 })
  end

  -- test_bnet_whisper_secret_account_id_filed_once
  do
    assertFiledOnce("BNet whisper with secret account ID", "CHAT_MSG_BN_WHISPER", { 13 })
  end

  -- test_bnet_whisper_only_guid_secret_filed_once_when_friend_in_game
  do
    local inGame = { playerGuid = "Player-2-DEF", characterName = "Arthas", isOnline = true }
    assertFiledOnce("BNet whisper with only a secret GUID (friend in game)", "CHAT_MSG_BN_WHISPER", { 12 }, inGame)
  end

  -- test_bnet_whisper_only_guid_secret_filed_once_without_game_guid
  do
    assertFiledOnce("BNet whisper with only a secret GUID (no game GUID)", "CHAT_MSG_BN_WHISPER", { 12 })
  end
end
