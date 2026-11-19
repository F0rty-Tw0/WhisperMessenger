local Store = require("WhisperMessenger.Model.ConversationStore")
local LivePresence = require("WhisperMessenger.Model.LivePresence")
local AddonMessage = require("WhisperMessenger.Core.EventRouter.AddonMessage")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local World = require("tests.helpers.character_merge_world")

-- Addon side-channel messages, called the way the router calls them once
-- the payload passed its secret-string check.
local KEY = "wow::WOW::arthas-area52"

local function newState()
  local state = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    availabilityByGUID = {},
    pendingOutgoing = {},
    questLinkInbox = {},
    now = function()
      return 100
    end,
  }
  Store.AppendIncoming(state.store, KEY, { id = "1", direction = "in", kind = "user", text = "hi", sentAt = 90, playerName = "Arthas-Area52" }, false)
  return state
end

local function test_character_typing_returns_the_conversation()
  local state = newState()
  local conversation, meta = AddonMessage.HandleCharacter(state, {
    prefix = "WMRX",
    text = LivePresence.EncodeTyping(true),
    channel = "WHISPER",
    playerName = "Arthas-Area52",
  })
  assert(conversation == state.store.conversations[KEY], "typing should resolve the sender's conversation")
  assert(meta and meta.presence == "typing" and meta.typingActive == true, "typing should report its presence meta")
end

local function test_character_unknown_prefix_is_ignored()
  local state = newState()
  local result = AddonMessage.HandleCharacter(state, { prefix = "OTHER", text = "x", channel = "WHISPER", playerName = "Arthas-Area52" })
  assert(result == nil and next(state.questLinkInbox) == nil, "an unknown prefix must change nothing")
end

local function test_character_quest_link_is_buffered_by_sender_name()
  local state = newState()
  AddonMessage.HandleCharacter(state, { prefix = "WMQL", text = "4641:Your Place In The World", channel = "WHISPER", playerName = "Arthas-Area52" })
  local inbox = state.questLinkInbox["Arthas-Area52"]
  assert(type(inbox) == "table" and inbox[1].id == "4641", "quest link should be buffered under the sender name")
end

local function test_battle_net_quest_link_is_buffered_by_account()
  local state = newState()
  local result = AddonMessage.HandleBattleNet(state, { prefix = "WMQL", text = "788:Cutting Teeth", bnetAccountID = 77 })
  local inbox = state.questLinkInbox["bn:77"]
  assert(result == nil and type(inbox) == "table" and inbox[1].id == "788", "quest link should be buffered under the account key")
end

local function test_battle_net_sender_key_links_the_game_account()
  local state = newState()
  assert(AddonMessage.BattleNetReactionSenderKey(state, { bnetAccountID = 77, gameAccountID = 9001 }) == "bn:77", "account id is the sender key")
  assert(AddonMessage.BattleNetReactionSenderKey(state, { gameAccountID = 9001 }) == "bn:77", "a known game account resolves to its account key")
  assert(AddonMessage.BattleNetReactionSenderKey(state, {}) == nil, "no ids, no sender key")
end

local function typing(state, playerName)
  return AddonMessage.HandleCharacter(
    state,
    { prefix = "WMRX", text = LivePresence.EncodeTyping(true), channel = "WHISPER", playerName = playerName }
  )
end

local function test_merged_character_typing_resolves_b()
  local state = World.MergedState()
  local conversation = typing(state, World.NAME)
  assert(conversation == state.store.conversations[World.B], "typing from a merged character should resolve the Battle.net chat")
end

-- The merge wins over the name lookup's bare-name match on another realm.
local function test_merged_same_realm_typing_beside_another_realm_resolves_b()
  local state = World.NewState(nil)
  World.SeedB(state)
  World.SeedK(state)
  CharacterMergeMap.Record(state.characterMerges, "wow::WOW::arthas", World.B, "Arthas")
  local conversation = typing(state, "Arthas")
  assert(conversation == state.store.conversations[World.B], "a merged same-realm character's typing shows in B, not in Arthas-Area52's chat")
end

return function()
  test_character_typing_returns_the_conversation()
  test_character_unknown_prefix_is_ignored()
  test_character_quest_link_is_buffered_by_sender_name()
  test_battle_net_quest_link_is_buffered_by_account()
  test_battle_net_sender_key_links_the_game_account()
  test_merged_character_typing_resolves_b()
  test_merged_same_realm_typing_beside_another_realm_resolves_b()
end
