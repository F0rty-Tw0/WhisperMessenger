local MessageMetadata = require("WhisperMessenger.Model.ConversationStore.MessageMetadata")

return function()
  -- test_group_chat_never_takes_the_senders_identity
  do
    local conversation = { channel = "WM_GROUP", displayName = "Crew" }
    MessageMetadata.ApplyContact({}, "wmgroup::abcd1234", conversation, {
      channel = "WM_GROUP",
      playerName = "Anna-Kazzak",
      guid = "Player-1-1",
      classTag = "MAGE",
    })
    assert(conversation.displayName == "Crew", "name kept")
    assert(conversation.guid == nil and conversation.classTag == nil, "no sender identity")
    assert(conversation.channel == "WM_GROUP")
  end

  -- test_party_chat_still_follows_the_last_sender
  do
    local conversation = { channel = "PARTY" }
    MessageMetadata.ApplyContact({}, "party::me", conversation, { channel = "PARTY", playerName = "Anna-Kazzak" })
    assert(conversation.displayName == "Anna-Kazzak")
  end
end
