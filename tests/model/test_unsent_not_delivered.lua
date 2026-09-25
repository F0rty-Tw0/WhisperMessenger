local Store = require("WhisperMessenger.Model.ConversationStore")
local LivePresence = require("WhisperMessenger.Model.LivePresence")

-- Queued and failed messages never reached the other side: they do not
-- answer an incoming message and can never be marked "Seen".
return function()
  -- test_queued_and_failed_do_not_answer_incoming
  for _, delivery in ipairs({ "queued", "failed" }) do
    local conversation = {
      messages = {
        { direction = "in", kind = "user", text = "hi" },
        { direction = "out", kind = "user", text = "later", delivery = delivery },
      },
    }
    assert(Store.CountUnansweredIncoming(conversation) == 1, delivery .. " outgoing must not answer incoming")
  end

  -- test_seen_receipt_skips_unsent_messages
  do
    local state = {
      store = {
        conversations = {
          k = {
            messages = {
              { direction = "out", kind = "user", text = "a", wireId = "w1" },
              { direction = "out", kind = "user", text = "b", delivery = "queued" },
              { direction = "out", kind = "user", text = "c", delivery = "failed" },
              { direction = "out", kind = "user", text = "d", wireId = "w2" },
            },
          },
        },
      },
    }
    LivePresence.MarkSeen(state, "k", "w2", 5)
    local messages = state.store.conversations.k.messages
    assert(messages[4].seenAt == 5 and messages[1].seenAt == 5, "delivered messages are seen")
    assert(messages[2].seenAt == nil and messages[3].seenAt == nil, "unsent messages are never seen")
  end
end
