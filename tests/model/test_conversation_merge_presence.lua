local ConversationMerge = require("WhisperMessenger.Model.ConversationMerge")

-- Re-keying keeps "Notify when online", the newest last-seen time, and only
-- keeps a message request when both records were requests (fail open).
return function()
  -- test_notify_and_last_seen_carry_over
  do
    local conversations = {
      old = { messages = {}, notifyOnline = true, lastSeenAt = 300 },
      new = { messages = {}, lastSeenAt = 100 },
    }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local merged = conversations.new
    assert(merged.notifyOnline == true, "notify flag carried over")
    assert(merged.lastSeenAt == 300, "newest last-seen kept")
  end

  -- test_request_needs_both_records
  do
    local conversations = { old = { messages = {}, request = true }, new = { messages = {} } }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    assert(conversations.new.request == nil, "an existing conversation is not a request")

    conversations = { old = { messages = {}, request = true }, new = { messages = {}, request = true } }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    assert(conversations.new.request == true, "both requests: still a request")
  end
end
