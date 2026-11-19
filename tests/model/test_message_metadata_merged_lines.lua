local Store = require("WhisperMessenger.Model.ConversationStore")
local MessageMetadata = require("WhisperMessenger.Model.ConversationStore.MessageMetadata")

-- A character's lines stored in their Battle.net friend's chat keep what
-- marks them as the character's (channel, name, class), and never turn the
-- chat into a character chat: replies must still go out over Battle.net.
local B = "bnet::BN::friend#1234"

local function friendChat(store)
  Store.AppendIncoming(store, B, {
    id = "1",
    direction = "in",
    kind = "user",
    text = "from the app",
    sentAt = 100,
    lineID = 1,
    playerName = "Friend#1234",
    channel = "BN",
    bnetAccountID = 42,
    battleTag = "Friend#1234",
    classTag = "PRIEST",
    guid = "Player-1-FRIENDCHAR",
  }, true)
  return store.conversations[B]
end

local function characterLine(direction, overrides)
  local message = {
    id = "2",
    direction = direction,
    kind = "user",
    text = "from the character",
    sentAt = 200,
    lineID = 2,
    playerName = "Arthas",
    channel = "WOW",
    guid = "Player-1-ARTHAS",
    classTag = "PALADIN",
  }
  for field, value in pairs(overrides or {}) do
    message[field] = value
  end
  return message
end

return function()
  -- test_incoming_character_line_in_battle_net_chat_keeps_its_marks
  do
    local store = Store.New({})
    friendChat(store)
    local line = characterLine("in", { classTag = "PRIEST" })
    Store.AppendIncoming(store, B, line, true)
    assert(line.channel == "WOW" and line.playerName == "Arthas", "the line keeps its channel and character name")
    assert(line.classTag == "PRIEST", "the line keeps its class even when it matches the chat's")
  end

  -- test_sent_character_line_in_battle_net_chat_keeps_its_marks
  do
    local store = Store.New({})
    friendChat(store)
    local line = characterLine("out")
    Store.AppendOutgoing(store, B, line)
    assert(line.channel == "WOW" and line.playerName == "Arthas" and line.classTag == "PALADIN", "a sent line to the character keeps its marks")
  end

  -- test_character_line_still_drops_the_guid
  do
    local store = Store.New({})
    friendChat(store)
    local line = characterLine("in")
    Store.AppendIncoming(store, B, line, true)
    assert(line.guid == nil, "the guid is not kept on the line")
  end

  -- test_incoming_character_line_leaves_battle_net_identity_alone
  do
    local store = Store.New({})
    local conversation = friendChat(store)
    Store.AppendIncoming(store, B, characterLine("in"), true)
    assert(conversation.channel == "BN", "the chat stays a Battle.net chat, got " .. tostring(conversation.channel))
    assert(conversation.displayName == "Friend#1234" and conversation.guid == "Player-1-FRIENDCHAR", "name and guid stay the friend's")
    assert(conversation.classTag == "PRIEST", "class stays the friend's, got " .. tostring(conversation.classTag))
    assert(conversation.bnetAccountID == 42 and conversation.battleTag == "Friend#1234", "the account stays")
  end

  -- test_sent_character_line_leaves_battle_net_channel_alone
  do
    local store = Store.New({})
    local conversation = friendChat(store)
    Store.AppendOutgoing(store, B, characterLine("out"))
    assert(conversation.channel == "BN", "a reply from this chat still goes over Battle.net")
  end

  -- test_newest_chronological_character_line_leaves_battle_net_identity_alone
  do
    local store = Store.New({})
    local conversation = friendChat(store)
    Store.InsertIncomingChronological(store, B, characterLine("in"), true)
    assert(conversation.channel == "BN" and conversation.displayName == "Friend#1234", "a replayed line keeps the friend's identity")
  end

  -- test_character_line_still_moves_activity_and_last_incoming
  do
    local store = Store.New({})
    local conversation = friendChat(store)
    Store.AppendIncoming(store, B, characterLine("in"), true)
    assert(conversation.lastActivityAt == 200 and conversation.lastPreview == "from the character", "activity and preview follow the line")
    assert(conversation.lastIncomingAt == 200 and conversation.lastIncomingPreview == "from the character", "last-incoming follows the line")
  end

  -- test_character_line_in_chat_without_a_channel_is_compacted
  do
    local store = Store.New({})
    local conversation = Store.EnsureConversation(store, "wow::WOW::arthas")
    local line = characterLine("out")
    MessageMetadata.Compact(line, conversation)
    assert(line.guid == nil, "the guid is dropped")
    assert(line.channel == nil and line.playerName == nil and line.classTag == nil, "only a Battle.net chat keeps a character's marks")
  end
end
