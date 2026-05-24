local QuestLinkExchange = require("WhisperMessenger.Model.QuestLinkExchange")

return function()
  -- 1. Encode returns nil for text without any quest references.
  do
    assert(QuestLinkExchange.Encode(nil) == nil, "nil text -> nil payload")
    assert(QuestLinkExchange.Encode("") == nil, "empty text -> nil payload")
    assert(QuestLinkExchange.Encode("just chatting") == nil, "plain chat -> nil payload")
    assert(QuestLinkExchange.Encode("[Just a label]") == nil, "bracket-only -> nil payload")
  end

  -- 2. Encode extracts ids+names from a real hyperlink envelope.
  do
    local input = "check |cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r please"
    local payload = QuestLinkExchange.Encode(input)
    assert(payload == "471:Apprentice's Duties", "encoded from hyperlink, got: " .. tostring(payload))
  end

  -- 3. Encode extracts ids+names from the plain `[Name (id)]` form too — the
  -- send-handler may have already serialized hyperlinks back to plain text.
  do
    local payload = QuestLinkExchange.Encode("check [Apprentice's Duties (471)] please")
    assert(payload == "471:Apprentice's Duties", "encoded from plain, got: " .. tostring(payload))
  end

  -- 4. Encode batches multiple quests separated by `;`.
  do
    local input = "[Foo (1)] and |cffffff00|Hquest:42:0|h[Bar Baz]|h|r"
    local payload = QuestLinkExchange.Encode(input)
    assert(payload == "1:Foo;42:Bar Baz", "batched payload, got: " .. tostring(payload))
  end

  -- 5. Encode skips entries that would push payload over the addon-message
  -- byte cap so the caller can still ship the first N quests safely.
  do
    local huge = string.rep("[X (1)]", 200) -- many tiny entries
    local payload = QuestLinkExchange.Encode(huge)
    assert(type(payload) == "string", "expected a string payload")
    assert(#payload <= 255, "expected payload to stay under 255 bytes, got: " .. tostring(#payload))
  end

  -- 6. RecordIncoming parses a payload string and buffers entries per sender.
  do
    local state = { questLinkInbox = {} }
    QuestLinkExchange.RecordIncoming(state, "Thrall-Nagrand", "471:Apprentice's Duties;42:Bar Baz", 1000)
    local buf = state.questLinkInbox["Thrall-Nagrand"]
    assert(type(buf) == "table" and #buf == 2, "expected two entries buffered")
    assert(buf[1].id == "471" and buf[1].name == "Apprentice's Duties", "first entry")
    assert(buf[2].id == "42" and buf[2].name == "Bar Baz", "second entry")
    assert(type(buf[1].recordedAt) == "number", "entries timestamped")
  end

  -- 7. Splice rewrites plain `[Name]` substrings into clickable hyperlinks
  -- when the matching id is buffered.
  do
    local state = { questLinkInbox = {} }
    QuestLinkExchange.RecordIncoming(state, "Thrall-Nagrand", "471:Apprentice's Duties", 1000)
    local out = QuestLinkExchange.Splice(state, "Thrall-Nagrand", "look at [Apprentice's Duties] please", 1001)
    local expected = "look at |cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r please"
    assert(out == expected, "expected spliced clickable link, got: " .. tostring(out))
  end

  -- 8. Splice consumes the buffer entry so a later unrelated whisper doesn't
  -- re-apply the link.
  do
    local state = { questLinkInbox = {} }
    QuestLinkExchange.RecordIncoming(state, "Thrall-Nagrand", "471:Apprentice's Duties", 1000)
    QuestLinkExchange.Splice(state, "Thrall-Nagrand", "[Apprentice's Duties] hi", 1001)
    local out2 = QuestLinkExchange.Splice(state, "Thrall-Nagrand", "[Apprentice's Duties] again", 1002)
    assert(out2 == "[Apprentice's Duties] again", "expected no second splice after buffer consumed, got: " .. tostring(out2))
  end

  -- 9. Splice ignores buffer entries older than 15 seconds (drift / mismatch).
  do
    local state = { questLinkInbox = {} }
    QuestLinkExchange.RecordIncoming(state, "Sender", "471:Apprentice's Duties", 1000)
    local out = QuestLinkExchange.Splice(state, "Sender", "[Apprentice's Duties]", 1020)
    assert(out == "[Apprentice's Duties]", "expired entry should not splice, got: " .. tostring(out))
  end

  -- 10. Splice is a no-op when no buffer exists for the sender.
  do
    local state = { questLinkInbox = {} }
    local out = QuestLinkExchange.Splice(state, "Stranger", "[Apprentice's Duties]", 1000)
    assert(out == "[Apprentice's Duties]", "no buffer -> text unchanged")
  end

  -- 11. Splice leaves already-clickable links untouched (idempotent).
  do
    local state = { questLinkInbox = {} }
    QuestLinkExchange.RecordIncoming(state, "Sender", "471:Apprentice's Duties", 1000)
    local already = "look at |cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r"
    local out = QuestLinkExchange.Splice(state, "Sender", already, 1001)
    assert(out == already, "real link unchanged, got: " .. tostring(out))
  end
  -- 12. RecordIncoming prunes expired unmatched side-channel buffers.
  do
    local state = { questLinkInbox = {} }
    QuestLinkExchange.RecordIncoming(state, "OldSender", "471:Apprentice's Duties", 1000)
    QuestLinkExchange.RecordIncoming(state, "NewSender", "42:Bar Baz", 1016)

    assert(state.questLinkInbox.OldSender == nil, "expired unmatched sender buffer should be pruned")
    assert(state.questLinkInbox.NewSender ~= nil, "new sender buffer should be retained")
  end
end
