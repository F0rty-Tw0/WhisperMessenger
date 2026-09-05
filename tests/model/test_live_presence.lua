local LivePresence = require("WhisperMessenger.Model.LivePresence")
local Store = require("WhisperMessenger.Model.ConversationStore")

local function newState()
  return {
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
  }
end

return function()
  -- test_encode_typing_payloads
  assert(LivePresence.EncodeTyping(true) == "1|T|1", "typing start payload")
  assert(LivePresence.EncodeTyping(false) == "1|T|0", "typing stop payload")

  -- test_decode_typing_payloads
  local typing = LivePresence.Decode("1|T|1")
  assert(typing and typing.type == "typing" and typing.active == true, "decode typing start")
  local stopped = LivePresence.Decode("1|T|0")
  assert(stopped and stopped.type == "typing" and stopped.active == false, "decode typing stop")

  -- test_encode_seen_requires_wire_id
  assert(LivePresence.EncodeSeen("abc123") == "1|S|abc123", "seen payload")
  assert(LivePresence.EncodeSeen("bad|id") == nil, "seen payload rejects separator in wire id")
  assert(LivePresence.EncodeSeen(nil) == nil, "seen payload rejects nil wire id")

  -- test_decode_seen_payload
  local seen = LivePresence.Decode("1|S|abc123")
  assert(seen and seen.type == "seen" and seen.wireId == "abc123", "decode seen")

  -- test_decode_rejects_foreign_or_malformed_payloads
  assert(LivePresence.Decode("1|I|abc|deadbeef") == nil, "identity payload is not presence")
  assert(LivePresence.Decode("2|T|1") == nil, "wrong version rejected")
  assert(LivePresence.Decode("1|T|x") == nil, "bad typing flag rejected")
  assert(LivePresence.Decode("1|T|1|extra") == nil, "extra typing field rejected")
  assert(LivePresence.Decode("1|S|bad id") == nil, "bad wire id rejected")
  assert(LivePresence.Decode(nil) == nil, "nil rejected")
  assert(LivePresence.Decode("") == nil, "empty rejected")

  -- test_typing_state_expires_after_ttl
  do
    local state = newState()
    LivePresence.SetTyping(state, "k", true, 100)
    assert(LivePresence.IsTyping(state, "k", 100), "typing right away")
    assert(LivePresence.IsTyping(state, "k", 100 + LivePresence.TYPING_TTL - 1), "typing inside ttl")
    assert(not LivePresence.IsTyping(state, "k", 100 + LivePresence.TYPING_TTL + 1), "typing expired after ttl")
    assert(not LivePresence.IsTyping(state, "other", 100), "unrelated conversation not typing")
  end

  -- test_typing_stop_clears_state
  do
    local state = newState()
    LivePresence.SetTyping(state, "k", true, 100)
    LivePresence.SetTyping(state, "k", false, 101)
    assert(not LivePresence.IsTyping(state, "k", 101), "stop clears typing")
  end

  -- test_set_typing_reports_change_on_start
  do
    local state = newState()
    assert(LivePresence.SetTyping(state, "k", true, 100) == true, "starting typing is a change")
  end

  -- test_set_typing_reports_no_change_on_repeat_inside_ttl
  do
    local state = newState()
    LivePresence.SetTyping(state, "k", true, 100)
    assert(LivePresence.SetTyping(state, "k", true, 101) == false, "repeat active packet inside ttl is no change")
  end

  -- test_set_typing_reports_change_on_stop
  do
    local state = newState()
    LivePresence.SetTyping(state, "k", true, 100)
    assert(LivePresence.SetTyping(state, "k", false, 101) == true, "stopping while typing is a change")
  end

  -- test_set_typing_reports_no_change_on_stop_when_idle
  do
    local state = newState()
    assert(LivePresence.SetTyping(state, "k", false, 100) == false, "stop while already idle is no change")
  end

  -- test_typing_remaining_counts_down_to_zero
  do
    local state = newState()
    LivePresence.SetTyping(state, "k", true, 100)
    assert(LivePresence.TypingRemaining(state, "k", 100) == LivePresence.TYPING_TTL, "full ttl remaining right away")
    assert(LivePresence.TypingRemaining(state, "k", 100 + LivePresence.TYPING_TTL - 1) == 1, "counts down")
    assert(LivePresence.TypingRemaining(state, "k", 100 + LivePresence.TYPING_TTL) == 0, "zero once expired")
    assert(LivePresence.TypingRemaining(state, "k", 100 + LivePresence.TYPING_TTL + 5) == 0, "zero stays zero past expiry")
    assert(LivePresence.TypingRemaining(state, "other", 100) == 0, "zero for unknown conversation")
  end

  -- test_peer_detection_is_remembered_and_persisted
  do
    local state = newState()
    assert(not LivePresence.HasPeer(state, "k"), "unknown peer by default")
    LivePresence.RecordPeer(state, "k")
    assert(LivePresence.HasPeer(state, "k"), "peer remembered before conversation exists")
    Store.EnsureConversation(state.store, "k")
    LivePresence.RecordPeer(state, "k")
    assert(state.store.conversations["k"].peerHasAddon == true, "peer flag persisted on conversation")
    local freshRuntime = { store = state.store }
    assert(LivePresence.HasPeer(freshRuntime, "k"), "persisted flag survives a fresh runtime")
    assert(not LivePresence.HasPeer(state, nil), "nil key is never a peer")
  end

  -- test_mark_seen_marks_target_and_earlier_outgoing_messages
  do
    local state = newState()
    local conv = Store.EnsureConversation(state.store, "k")
    conv.messages = {
      { direction = "out", kind = "user", wireId = "w1", text = "a" },
      { direction = "in", kind = "user", wireId = "i1", text = "b" },
      { direction = "out", kind = "user", wireId = "w2", text = "c" },
      { direction = "out", kind = "user", wireId = "w3", text = "d" },
    }
    assert(LivePresence.MarkSeen(state, "k", "w2", 500) == 2, "two messages newly seen")
    assert(conv.messages[1].seenAt == 500 and conv.messages[3].seenAt == 500, "target and earlier outgoing marked")
    assert(conv.messages[2].seenAt == nil, "incoming never marked")
    assert(conv.messages[4].seenAt == nil, "newer outgoing not marked")
    assert(LivePresence.MarkSeen(state, "k", "w2", 600) == 0, "idempotent")
    assert(conv.messages[1].seenAt == 500, "original seen time kept")
    assert(LivePresence.MarkSeen(state, "k", "nope", 600) == 0, "unknown wire id ignored")
    assert(LivePresence.MarkSeen(state, "missing", "w1", 600) == 0, "missing conversation ignored")
  end

  -- test_next_receipt_returns_newest_unreceipted_incoming_with_wire_id
  do
    local conv = {
      messages = {
        { direction = "out", kind = "user", wireId = "w1", text = "a" },
        { direction = "in", kind = "user", wireId = "i1", text = "b" },
      },
    }
    assert(LivePresence.NextReceipt(conv) == conv.messages[2], "newest incoming needs receipt")
    conv.messages[2].receiptSentAt = 700
    assert(LivePresence.NextReceipt(conv) == nil, "already receipted")
    table.insert(conv.messages, { direction = "in", kind = "user", text = "no wire" })
    assert(LivePresence.NextReceipt(conv) == nil, "messages without wire id are skipped")
    table.insert(conv.messages, { direction = "in", kind = "system", wireId = "sys", text = "afk" })
    assert(LivePresence.NextReceipt(conv) == nil, "system messages never receipted")
    table.insert(conv.messages, { direction = "in", kind = "user", wireId = "i2", text = "x" })
    assert(LivePresence.NextReceipt(conv).wireId == "i2", "new incoming needs receipt")
    assert(LivePresence.NextReceipt(nil) == nil, "nil conversation")
  end
end
