local Router = require("WhisperMessenger.Core.EventRouter")
local CharacterMergeRemap = require("WhisperMessenger.Core.Bootstrap.CharacterMergeRemap")
local MessageReactions = require("WhisperMessenger.Model.MessageReactions")
local MessageReplies = require("WhisperMessenger.Model.MessageReplies")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local World = require("tests.helpers.character_merge_world")

-- The addon side channel keys a character sender by the character's chat key.
-- When its packets beat the whisper that folds the chat into the friend's
-- chat, they must still pair with that whisper in the friend's chat.
local K, B, NAME = World.K, World.B, World.NAME

local function mergingState()
  local state = World.NewState(World.FRIEND)
  World.SeedB(state)
  World.SeedK(state, {
    id = "50",
    lineID = 50,
    kind = "user",
    direction = "in",
    text = "earlier",
    sentAt = 500,
    channel = "WOW",
    playerName = NAME,
    wireId = "old1",
  })
  state.onCharacterMerged = function(characterKey, bnetKey)
    CharacterMergeRemap.Apply(state, characterKey, bnetKey)
  end
  return state
end

local function whisper(state)
  Router.HandleEvent(state, "CHAT_MSG_WHISPER", { text = "hello", playerName = NAME, guid = "Player-1", lineID = 900 })
  return World.Last(state.store.conversations[B])
end

local function identityFirst(state)
  local metadata = { type = "identity", wireId = "w123", sourceFingerprint = Protocol.Fingerprint("hello") }
  MessageReactions.RecordIdentity(state, K, K, metadata, 1000)
end

return function()
  -- test_identity_before_the_merging_whisper_pairs_in_the_friend_chat
  do
    local state = mergingState()
    identityFirst(state)
    local line = whisper(state)
    assert(line.text == "hello", "the whisper lands in the friend's chat")
    assert(line.wireId == "w123", "the waiting identity pairs with the whisper, got " .. tostring(line.wireId))
  end

  -- test_reply_link_before_the_merging_whisper_attaches_its_quote
  do
    local state = mergingState()
    identityFirst(state)
    MessageReplies.ApplyLink(state, K, MessageReplies.DecodeLink("1|Q|w123|old1|M"), 1000)
    local line = whisper(state)
    assert(line.replyTo ~= nil and line.replyTo.wireId == "old1", "the waiting quote attaches in the friend's chat")
  end
end
