local Store = require("WhisperMessenger.Model.ConversationStore")

-- Store.NewRecord builds the record EnsureConversation stores, without
-- storing it.
local KEY = "bnet::BN::jaina#1234"

return function()
  -- test_new_record_has_the_empty_conversation_shape
  do
    local record = Store.NewRecord(KEY)
    assert(record.conversationKey == KEY and #record.messages == 0, "a new record is an empty chat under its key")
    assert(record.unreadCount == 0 and record.unreadActivityCount == 0 and record.lastActivityAt == 0, "a new record starts with nothing unread")
  end

  -- test_new_record_copies_known_metadata
  do
    local record = Store.NewRecord(KEY, { channel = "BN", battleTag = "Jaina#1234", bnetAccountID = 77 })
    assert(record.channel == "BN" and record.battleTag == "Jaina#1234" and record.bnetAccountID == 77, "known fields are copied")
  end

  -- test_new_record_ignores_unknown_metadata
  do
    local record = Store.NewRecord(KEY, { contactKey = "BN::jaina#1234", canonicalName = "jaina#1234" })
    assert(record.contactKey == nil and record.canonicalName == nil, "fields the store does not keep are left out")
  end

  -- test_ensure_conversation_stores_the_same_shape
  do
    local store = Store.New({})
    local stored = Store.EnsureConversation(store, KEY, { channel = "BN", battleTag = "Jaina#1234" })
    local built = Store.NewRecord(KEY, { channel = "BN", battleTag = "Jaina#1234" })
    for field, value in pairs(built) do
      if type(value) ~= "table" then
        assert(stored[field] == value, "EnsureConversation stores NewRecord's " .. field)
      end
    end
  end
end
