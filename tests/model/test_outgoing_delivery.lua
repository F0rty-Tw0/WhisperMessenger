local OutgoingDelivery = require("WhisperMessenger.Model.OutgoingDelivery")
local ConversationMerge = require("WhisperMessenger.Model.ConversationMerge")

-- Outgoing messages that did not go out normally: "queued" (written during
-- chat lockdown, waits for a Send now click), "blocked" (the same thing from
-- before queueing existed) and "failed" (the game said the whisper could not
-- be delivered).

local function newStore()
  return {
    conversations = {
      a = {
        messages = {
          { id = "1", direction = "in", kind = "user", text = "hi" },
          { id = "2", direction = "out", kind = "user", text = "later", delivery = "queued" },
        },
        lastPreview = "later",
      },
      b = {
        messages = {
          { id = "3", direction = "out", kind = "user", text = "x", delivery = "queued" },
          { id = "4", direction = "out", kind = "user", text = "y", delivery = "failed" },
          { id = "5", direction = "out", kind = "user", text = "z", delivery = "blocked" },
        },
      },
    },
  }
end

return function()
  -- test_status_maps_delivery_to_a_label
  do
    assert(OutgoingDelivery.Status({ direction = "out", delivery = "queued" }) == "queued", "queued")
    assert(OutgoingDelivery.Status({ direction = "out", delivery = "blocked" }) == "notSent", "old blocked = not sent")
    assert(OutgoingDelivery.Status({ direction = "out", delivery = "failed" }) == "notSent", "failed = not sent")
    assert(OutgoingDelivery.Status({ direction = "out" }) == nil, "normal send shows nothing")
    assert(OutgoingDelivery.Status({ direction = "in", delivery = "queued" }) == nil, "incoming never has a status")
    assert(OutgoingDelivery.Status(nil) == nil, "nil safe")
  end

  -- test_actions_per_status
  do
    local queued = OutgoingDelivery.Actions({ direction = "out", delivery = "queued" }, true)
    assert(#queued == 1 and queued[1] == "discard", "locked: queued offers Discard only")
    local ready = OutgoingDelivery.Actions({ direction = "out", delivery = "queued" }, false)
    assert(#ready == 2 and ready[1] == "send_now" and ready[2] == "discard", "unlocked: Send now + Discard")
    local blocked = OutgoingDelivery.Actions({ direction = "out", delivery = "blocked" }, false)
    assert(#blocked == 1 and blocked[1] == "discard", "old blocked: Discard only")
    local failed = OutgoingDelivery.Actions({ direction = "out", delivery = "failed" }, false)
    assert(#failed == 2 and failed[1] == "retry" and failed[2] == "discard", "failed: Retry + Discard")
    assert(#OutgoingDelivery.Actions({ direction = "out" }, false) == 0, "normal message: no actions")
  end

  -- test_count_queued_counts_only_queued
  do
    assert(OutgoingDelivery.CountQueued(newStore()) == 2, "two queued across conversations")
    assert(OutgoingDelivery.CountQueued({}) == 0, "empty store")
    assert(OutgoingDelivery.CountQueued(nil) == 0, "nil store")
  end

  -- test_remove_drops_the_exact_message_and_fixes_preview
  do
    local store = newStore()
    local queued = store.conversations.a.messages[2]
    assert(OutgoingDelivery.Remove(store, "a", queued) == true, "removed")
    assert(#store.conversations.a.messages == 1, "one message left")
    assert(store.conversations.a.lastPreview == "hi", "preview falls back to the new last message")
    assert(OutgoingDelivery.Remove(store, "a", queued) == false, "second remove is a no-op")
    assert(OutgoingDelivery.Remove(store, "missing", queued) == false, "unknown conversation")
  end

  -- test_build_record_keeps_the_send_target
  do
    local record = OutgoingDelivery.BuildRecord({
      target = "Thrall-Nagrand",
      displayName = "Thrall",
      channel = "WOW",
      guid = "Player-1",
      text = "hello",
      replyTo = { wireId = "abc" },
    }, 50, "queued", "Mythic Lockdown")
    assert(record.direction == "out" and record.kind == "user", "outgoing user message")
    assert(record.delivery == "queued" and record.blockedReason == "Mythic Lockdown", "delivery + reason")
    assert(record.target == "Thrall-Nagrand" and record.playerName == "Thrall", "target kept for Send now")
    assert(record.guid == "Player-1" and record.channel == "WOW" and record.text == "hello", "fields kept")
    assert(record.sentAt == 50 and string.find(record.id, "^50%-%d+$") ~= nil, "timestamped, unique id: " .. tostring(record.id))
    assert(record.replyTo.wireId == "abc", "reply link kept")
  end

  -- Two unsent messages in the same second must keep distinct ids, or merging
  -- chat histories drops one of them as a duplicate.
  do
    local first = OutgoingDelivery.BuildRecord({ text = "one" }, 100, "queued")
    local second = OutgoingDelivery.BuildRecord({ text = "two" }, 100, "queued")

    -- test_ids_are_unique_within_one_second
    assert(first.id ~= second.id, "same-second records get different ids: " .. tostring(first.id))

    -- test_merge_keeps_both_same_second_records
    local conversations = {
      old = { messages = { first } },
      new = { messages = { second } },
    }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    assert(#conversations.new.messages == 2, "both queued messages survive the merge")
  end
end
