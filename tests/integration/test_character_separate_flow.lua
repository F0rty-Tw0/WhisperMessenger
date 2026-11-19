local Store = require("WhisperMessenger.Model.ConversationStore")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local CharacterSeparate = require("WhisperMessenger.Model.CharacterSeparate")
local Router = require("WhisperMessenger.Core.EventRouter")

-- After "Separate", the character's next whisper goes to the character's own
-- chat even though the game still says it belongs to the Battle.net friend.
local K = "wow::WOW::arthas"
local NAME = "Arthas"
local K_OTHER_REALM = "wow::WOW::arthas-area52"
local NAME_OTHER_REALM = "Arthas-Area52"
local B = "bnet::BN::jaina#1234"
local FRIEND = { bnetAccountID = 77, battleTag = "Jaina#1234" }

local function newRuntime()
  local lookups = { n = 0 }
  local runtime = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 50, maxConversations = 10 }),
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 1000
    end,
    accountState = { settings = {} },
    characterMerges = CharacterMergeMap.Ensure({}),
    bnetApi = {
      GetAccountInfoByGUID = function()
        lookups.n = lookups.n + 1
        return FRIEND
      end,
    },
  }
  Store.EnsureConversation(runtime.store, B, { channel = "BN", displayName = "Jaina#1234", battleTag = "Jaina#1234", bnetAccountID = 77 })
  local friend = runtime.store.conversations[B]
  friend.messages = {
    { id = "20", lineID = 20, kind = "user", direction = "in", text = "k old", sentAt = 200, channel = "WOW", playerName = NAME },
    { id = "40", lineID = 40, kind = "user", direction = "in", text = "other realm", sentAt = 400, channel = "WOW", playerName = NAME_OTHER_REALM },
  }
  friend.lastActivityAt = 400
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  CharacterMergeMap.Record(runtime.characterMerges, K_OTHER_REALM, B, NAME_OTHER_REALM)
  return runtime, lookups
end

local function whisper(runtime, name, text, lineID)
  return Router.HandleEvent(runtime, "CHAT_MSG_WHISPER", { text = text, playerName = name, guid = "Player-1", lineID = lineID })
end

local function last(conversation)
  return conversation.messages[#conversation.messages]
end

return function()
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil

  local ok, err = pcall(function()
    -- test_separated_character_whisper_stays_in_its_own_chat
    do
      local runtime, lookups = newRuntime()
      CharacterSeparate.Separate(runtime.store, runtime.characterMerges, B, K)
      whisper(runtime, NAME, "hello again", 700)
      local character = runtime.store.conversations[K]
      assert(
        character ~= nil and #character.messages == 2 and last(character).text == "hello again",
        "the next whisper lands in the character's chat"
      )
      assert(#runtime.store.conversations[B].messages == 1, "the friend's chat does not take it")
      assert(lookups.n == 0, "a separated character is never looked up again")
      assert(CharacterMergeMap.Get(runtime.characterMerges, K) == nil, "and is not merged again")
    end

    -- test_other_realm_character_still_lands_in_the_friend_chat
    do
      local runtime = newRuntime()
      CharacterSeparate.Separate(runtime.store, runtime.characterMerges, B, K)
      whisper(runtime, NAME_OTHER_REALM, "still merged", 701)
      assert(last(runtime.store.conversations[B]).text == "still merged", "the character from the other realm stays in the friend's chat")
      assert(runtime.store.conversations[K_OTHER_REALM] == nil, "no chat of its own")
    end
  end)

  _G.C_Timer = savedTimer
  assert(ok, err)
end
