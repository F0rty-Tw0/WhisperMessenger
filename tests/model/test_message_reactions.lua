local protocolLoaded, Protocol = pcall(require, "WhisperMessenger.Model.MessageReactionProtocol")
local reactionsLoaded, MessageReactions = pcall(require, "WhisperMessenger.Model.MessageReactions")

local function newState()
  return {
    store = {
      conversations = {},
    },
    now = function()
      return 0
    end,
  }
end

local function addConversation(state, key, messages)
  state.store.conversations[key] = {
    conversationKey = key,
    messages = messages,
    unreadCount = 0,
    lastPreview = messages[#messages] and messages[#messages].text or nil,
    lastActivityAt = messages[#messages] and messages[#messages].sentAt or 0,
  }
  return state.store.conversations[key]
end

return function()
  assert(protocolLoaded, "MessageReactionProtocol module should load before reaction state behavior can pass")
  assert(reactionsLoaded, "MessageReactions module should load before reaction state behavior can pass")

  do
    assert(MessageReactions.IsEligible({ kind = "user", direction = "in", channel = "WOW" }) == true, "incoming WOW user message should be eligible")
    assert(
      MessageReactions.IsEligible({ kind = "user", direction = "in", channel = false }, "WOW") == false,
      "explicit false channel should not use WOW override"
    )
    for _, channel in ipairs({ "PARTY", "RAID", "INSTANCE_CHAT", "GUILD", "OFFICER" }) do
      assert(
        MessageReactions.IsEligible({ kind = "user", direction = "in", channel = channel }, channel) == true,
        channel .. " incoming user message should be eligible"
      )
    end
    assert(
      MessageReactions.IsEligible({ kind = "user", direction = "in", channel = "CHANNEL" }, "CHANNEL") == false,
      "numbered channels must remain ineligible"
    )
    assert(
      MessageReactions.IsEligible({ kind = "user", direction = "in", channel = "PARTY" }, "WOW") == false,
      "mismatched group contact channel must be ineligible"
    )
    assert(
      MessageReactions.IsEligible({ kind = "user", direction = "in", channel = "WOW" }, "PARTY") == false,
      "mismatched whisper contact channel must be ineligible"
    )
    assert(
      MessageReactions.IsEligible({ kind = "user", direction = "in", channel = "PARTY" }) == true,
      "incoming PARTY message should be eligible without an override"
    )
    assert(
      MessageReactions.IsEligible({ kind = "user", direction = "in", channel = "WOW", isCensored = true }) == false,
      "unrevealed censored message should be ineligible"
    )
    assert(MessageReactions.IsEligible({ kind = "user", direction = "out", channel = "WOW" }) == false, "outgoing message should be ineligible")
    assert(MessageReactions.IsEligible({ kind = "system", direction = "in", channel = "WOW" }) == false, "system message should be ineligible")
    assert(
      MessageReactions.IsEligible({ kind = "channel_context", direction = "in", channel = "WOW" }) == false,
      "channel context should be ineligible"
    )
    assert(
      MessageReactions.IsEligible({ kind = "user", direction = "in", channel = "WOW", delivery = "blocked" }) == false,
      "blocked message should be ineligible"
    )
  end

  -- Identity metadata may arrive before its matching whisper.
  do
    local state = newState()
    local message = { kind = "user", direction = "in", text = "same", sentAt = 101 }
    MessageReactions.RecordIdentity(state, "Arthas", "conv-a", {
      type = "identity",
      wireId = "wire1",
      sourceFingerprint = Protocol.Fingerprint(message.text),
    }, 100)
    local attached = MessageReactions.AttachIncomingIdentity(state, "Arthas", "conv-a", message, 101)
    assert(attached == true and message.wireId == "wire1", "metadata-before-message should attach shared wire ID")
  end

  -- The whisper may arrive before identity metadata too.
  do
    local state = newState()
    local message = { kind = "user", direction = "in", text = "early", sentAt = 100 }
    assert(MessageReactions.AttachIncomingIdentity(state, "Arthas", "conv-a", message, 100) == false, "unmatched whisper should stage")
    local attached = MessageReactions.RecordIdentity(state, "Arthas", "conv-a", {
      type = "identity",
      wireId = "wire2",
      sourceFingerprint = Protocol.Fingerprint(message.text),
    }, 101)
    assert(attached == message and message.wireId == "wire2", "message-before-metadata should attach shared wire ID")
  end

  -- Duplicate identical messages pair in FIFO order, not newest-first.
  do
    local state = newState()
    local first = { kind = "user", direction = "in", text = "duplicate", sentAt = 100 }
    local second = { kind = "user", direction = "in", text = "duplicate", sentAt = 101 }
    MessageReactions.AttachIncomingIdentity(state, "Arthas", "conv-a", first, 100)
    MessageReactions.AttachIncomingIdentity(state, "Arthas", "conv-a", second, 101)
    MessageReactions.RecordIdentity(state, "Arthas", "conv-a", {
      type = "identity",
      wireId = "firstWire",
      sourceFingerprint = Protocol.Fingerprint("duplicate"),
    }, 102)
    MessageReactions.RecordIdentity(state, "Arthas", "conv-a", {
      type = "identity",
      wireId = "secondWire",
      sourceFingerprint = Protocol.Fingerprint("duplicate"),
    }, 103)
    assert(first.wireId == "firstWire", "first duplicate should receive first metadata ID")
    assert(second.wireId == "secondWire", "second duplicate should receive second metadata ID")
  end

  do
    local state = newState()
    MessageReactions.RecordIdentity(state, "Arthas", "conv-a", {
      type = "identity",
      wireId = "expiredWire",
      sourceFingerprint = Protocol.Fingerprint("late"),
    }, 100)
    local late = { kind = "user", direction = "in", text = "late", sentAt = 115 }
    assert(MessageReactions.AttachIncomingIdentity(state, "Arthas", "conv-a", late, 115) == false, "identity metadata should expire after 15 seconds")
    assert(late.wireId == nil, "expired identity metadata must not attach")
  end

  -- Shared wire IDs target an exact duplicate inside one conversation.
  do
    local state = newState()
    local first = { kind = "user", direction = "out", text = "duplicate", wireId = "wire-a", sentAt = 90 }
    local second = { kind = "user", direction = "out", text = "duplicate", wireId = "wire-b", sentAt = 91 }
    local other = { kind = "user", direction = "out", text = "duplicate", wireId = "wire-a", sentAt = 92 }
    addConversation(state, "conv-a", { first, second })
    addConversation(state, "conv-b", { other })

    local operation = {
      type = "reaction",
      operation = "set",
      key = "heart",
      wireId = "wire-a",
      sourceFingerprint = Protocol.Fingerprint("duplicate"),
      fallbackFingerprint = Protocol.Fingerprint("fallback"),
    }
    local changed, target = MessageReactions.ApplyOperation(state, "conv-a", operation, "Arthas", "out", 100)
    assert(changed == true and target == first, "wire ID should select exact target")
    assert(first.reaction and first.reaction.key == "heart", "set should store reaction")
    assert(second.reaction == nil and other.reaction == nil, "wire target must stay conversation-scoped")
    assert(first.reaction.actorName == "Arthas" and first.reaction.updatedAt == 100, "reaction should store actor and update time")

    local replayChanged = MessageReactions.ApplyOperation(state, "conv-a", operation, "Arthas", "out", 110)
    assert(replayChanged == false, "replayed set operation should be idempotent")
    assert(first.reaction.updatedAt == 100, "idempotent replay should not alter stored time")

    operation.key = "thumbsup"
    assert(MessageReactions.ApplyOperation(state, "conv-a", operation, "Arthas", "out", 120) == true, "different key should replace")
    assert(first.reaction.key == "thumbsup", "replace should retain one reaction")

    operation.operation = "remove"
    assert(MessageReactions.ApplyOperation(state, "conv-a", operation, "Arthas", "out", 130) == true, "remove should clear selected reaction")
    assert(first.reaction == nil, "remove should clear reaction state")
    assert(MessageReactions.ApplyOperation(state, "conv-a", operation, "Arthas", "out", 140) == false, "replayed remove should be idempotent")
  end

  -- Legacy messages without shared IDs use newest matching text fingerprint.
  do
    local state = newState()
    local older = { kind = "user", direction = "out", text = "legacy duplicate", sentAt = 90 }
    local incoming = { kind = "user", direction = "in", text = "legacy duplicate", sentAt = 91 }
    local newer = { kind = "user", direction = "out", text = "legacy duplicate", sentAt = 92 }
    addConversation(state, "conv-a", { older, incoming, newer })
    local operation = {
      type = "reaction",
      operation = "set",
      key = "gg",
      sourceFingerprint = Protocol.Fingerprint("legacy duplicate"),
      fallbackFingerprint = Protocol.Fingerprint("fallback"),
    }
    local changed, target = MessageReactions.ApplyOperation(state, "conv-a", operation, "Arthas", "out", 100)
    assert(changed == true and target == newer, "legacy lookup should select newest exact expected-direction text")
    assert(older.reaction == nil and incoming.reaction == nil, "legacy lookup should not mutate older or wrong-direction messages")
  end

  -- A nil-wire legacy operation still targets the newest fingerprint match if
  -- that retained target acquired a wire ID after the sender captured it.
  do
    local state = newState()
    local older = { kind = "user", direction = "out", text = "race duplicate", sentAt = 90 }
    local newer = { kind = "user", direction = "out", text = "race duplicate", wireId = "late-wire", sentAt = 91 }
    addConversation(state, "conv-a", { older, newer })
    local operation = {
      type = "reaction",
      operation = "set",
      key = "heart",
      sourceFingerprint = Protocol.Fingerprint("race duplicate"),
      fallbackFingerprint = Protocol.Fingerprint("fallback"),
    }
    local changed, target = MessageReactions.ApplyOperation(state, "conv-a", operation, "Arthas", "out", 100)
    assert(changed == true and target == newer, "nil-wire race should select newest fingerprint match even after target gains wire ID")
    assert(older.reaction == nil, "nil-wire race must not fall back to an older wireless duplicate")
  end

  -- Operation metadata before normal fallback converts only when fallback arrives.
  do
    local state = newState()
    local target = { kind = "user", direction = "out", text = "Ready?", wireId = "wire1", sentAt = 90 }
    addConversation(state, "conv-a", { target })
    local fallback = Protocol.BuildFallback("heart", "set", target.text)
    local operation = assert(Protocol.Decode(Protocol.EncodeReaction("set", "heart", target.wireId, target.text, fallback)))

    assert(MessageReactions.RecordOperation(state, "Arthas", "conv-a", "Arthas", operation, "out", 100) == nil, "unmatched operation should stage")
    assert(target.reaction == nil, "metadata alone must not apply a reaction")

    local degraded = 0
    local result = MessageReactions.ConsumeIncomingControl(
      state,
      "Arthas",
      "conv-a",
      "Arthas",
      {
        kind = "user",
        direction = "in",
        text = fallback,
        sentAt = 101,
      },
      "out",
      101,
      function()
        degraded = degraded + 1
      end
    )
    assert(result and result.converted == true and result.changed == true, "operation-before-fallback should convert")
    assert(target.reaction and target.reaction.key == "heart", "converted fallback should apply reaction")
    assert(degraded == 0, "converted control should never degrade to history")
  end

  -- Normal fallback before operation stages without visible effects, then converts.
  do
    local state = newState()
    local target = { kind = "user", direction = "out", text = "Ready?", wireId = "wire2", sentAt = 90 }
    addConversation(state, "conv-a", { target })
    local fallback = Protocol.BuildFallback("question", "set", target.text)
    local controlMessage = { kind = "user", direction = "in", text = fallback, sentAt = 100 }
    local degraded = 0
    local staged = MessageReactions.ConsumeIncomingControl(state, "Arthas", "conv-a", "Arthas", controlMessage, "out", 100, function()
      degraded = degraded + 1
    end)
    assert(staged and staged.staged == true, "recognized fallback should stage while awaiting metadata")
    assert(target.reaction == nil and degraded == 0, "staging must not mutate state or degrade early")

    local operation = assert(Protocol.Decode(Protocol.EncodeReaction("set", "question", target.wireId, target.text, fallback)))
    local converted = MessageReactions.RecordOperation(state, "Arthas", "conv-a", "Arthas", operation, "out", 101)
    assert(converted and converted.converted == true and converted.changed == true, "fallback-before-operation should convert")
    assert(target.reaction and target.reaction.key == "question", "late metadata should apply reaction")
    assert(degraded == 0, "converted staged control should not degrade")
  end

  -- Missing metadata degrades recognized fallback to an ordinary readable whisper at TTL.
  do
    local state = newState()
    local fallback = Protocol.BuildFallback("sad", "set", "Gone?")
    local controlMessage = { kind = "user", direction = "in", text = fallback, sentAt = 100 }
    local degradedMessage
    MessageReactions.ConsumeIncomingControl(state, "Arthas", "conv-a", "Arthas", controlMessage, "out", 100, function(message)
      degradedMessage = message
    end)
    assert(degradedMessage == nil, "fallback should remain hidden during correlation TTL")
    MessageReactions.Expire(state, 114)
    assert(degradedMessage == nil, "fallback should remain staged before 15 seconds")
    MessageReactions.Expire(state, 115)
    assert(degradedMessage == controlMessage, "missing metadata should degrade to original readable message at 15 seconds")
  end

  -- Missing target degrades immediately once both transport halves are known.
  do
    local state = newState()
    addConversation(state, "conv-a", {})
    local fallback = Protocol.BuildFallback("angry", "set", "Missing")
    local operation = assert(Protocol.Decode(Protocol.EncodeReaction("set", "angry", "missingWire", "Missing", fallback)))
    MessageReactions.RecordOperation(state, "Arthas", "conv-a", "Arthas", operation, "out", 100)
    local controlMessage = { kind = "user", direction = "in", text = fallback, sentAt = 101 }
    local degradedMessage
    local result = MessageReactions.ConsumeIncomingControl(state, "Arthas", "conv-a", "Arthas", controlMessage, "out", 101, function(message)
      degradedMessage = message
    end)
    assert(result and result.degraded == true, "matched control with missing target should degrade")
    assert(degradedMessage == controlMessage, "missing target should preserve readable fallback")
  end

  -- Batched expiry preserves the original arrival order of readable fallbacks.
  do
    local savedTimer = _G.C_Timer
    _G.C_Timer = nil
    local state = newState()
    local degraded = {}
    local first = { kind = "user", direction = "in", text = Protocol.BuildFallback("heart", "set", "First"), sentAt = 100 }
    local second = { kind = "user", direction = "in", text = Protocol.BuildFallback("heart", "set", "Second"), sentAt = 105 }
    MessageReactions.ConsumeIncomingControl(state, "Arthas", "conv-a", "Arthas", first, "out", 100, function(message)
      degraded[#degraded + 1] = message
    end)
    MessageReactions.ConsumeIncomingControl(state, "Arthas", "conv-a", "Arthas", second, "out", 105, function(message)
      degraded[#degraded + 1] = message
    end)
    MessageReactions.Expire(state, 120)
    assert(degraded[1] == first and degraded[2] == second, "batched degradation should retain FIFO message order")
    _G.C_Timer = savedTimer
  end

  -- Cleanup coalesces to the earliest deadline and reschedules the next.
  do
    local savedTimer = _G.C_Timer
    local scheduled = {}
    local now = 100
    _G.C_Timer = {
      After = function(delay, callback)
        scheduled[#scheduled + 1] = { delay = delay, callback = callback }
      end,
    }
    local state = newState()
    state.now = function()
      return now
    end
    local degraded = {}
    local first = { kind = "user", direction = "in", text = Protocol.BuildFallback("heart", "set", "One"), sentAt = 100 }
    MessageReactions.ConsumeIncomingControl(state, "Arthas", "conv-a", "Arthas", first, "out", 100, function(message)
      degraded[#degraded + 1] = message
    end)
    now = 105
    local second = { kind = "user", direction = "in", text = Protocol.BuildFallback("heart", "set", "Two"), sentAt = 105 }
    MessageReactions.ConsumeIncomingControl(state, "Arthas", "conv-a", "Arthas", second, "out", 105, function(message)
      degraded[#degraded + 1] = message
    end)
    assert(#scheduled == 1 and scheduled[1].delay == 15, "staged fallbacks should share one earliest cleanup timer")
    now = 115
    scheduled[1].callback()
    assert(#degraded == 1 and degraded[1] == first, "first timer should degrade only first fallback at its deadline")
    assert(#scheduled == 2 and scheduled[2].delay == 5, "cleanup should reschedule for second deadline")
    now = 120
    scheduled[2].callback()
    assert(#degraded == 2 and degraded[2] == second, "second timer should degrade second fallback at its deadline")
    _G.C_Timer = savedTimer
  end

  do
    local state = newState()
    local ordinary = { kind = "user", direction = "in", text = "ordinary whisper", sentAt = 100 }
    assert(
      MessageReactions.ConsumeIncomingControl(state, "Arthas", "conv-a", "Arthas", ordinary, "out", 100, function() end) == nil,
      "ordinary whisper should bypass reaction staging"
    )
  end
  -- Group reactions target either direction only when the encoded author
  -- identity, wire ID, and text fingerprint all agree.
  do
    local state = newState()
    local outgoing = {
      kind = "user",
      direction = "out",
      text = "duplicate",
      wireId = "samewire",
      guid = "Player-local",
      playerName = "Me-Realm",
    }
    local incoming = {
      kind = "user",
      direction = "in",
      text = "duplicate",
      wireId = "samewire",
      guid = "Player-other",
      playerName = "Other-Realm",
    }
    addConversation(state, "group-current", { outgoing, incoming })
    local fallback = Protocol.BuildGroupFallback("heart", "set", outgoing.text)
    local operation =
      assert(Protocol.Decode(Protocol.EncodeGroupReaction("set", "heart", "samewire", outgoing.text, fallback, outgoing.guid, outgoing.playerName)))
    local changed, target = MessageReactions.ApplyOperation(state, "group-current", operation, "Other-Realm", nil, 100)
    assert(changed == true and target == outgoing, "group target GUID/name should select outgoing original-author bubble")
    assert(incoming.reaction == nil, "same-text message from another author must not cross-target")

    operation =
      assert(Protocol.Decode(Protocol.EncodeGroupReaction("set", "heart", "samewire", incoming.text, fallback, incoming.guid, incoming.playerName)))
    changed, target = MessageReactions.ApplyOperation(state, "group-current", operation, "Third-Realm", nil, 101)
    assert(changed == true and target == incoming, "group target GUID/name should select incoming third-peer bubble")
    incoming.reaction = nil
    operation = assert(Protocol.Decode(Protocol.EncodeGroupReaction("set", "heart", "samewire", incoming.text, fallback, incoming.guid, "")))
    changed, target = MessageReactions.ApplyOperation(state, "group-current", operation, "Third-Realm", nil, 102)
    assert(changed == true and target == incoming, "group GUID target should not require a name")
  end
  -- Legacy group metadata without a wire ID must still target its original
  -- author by fingerprint, in either direction, without crossing duplicate
  -- author names.
  do
    local state = newState()
    local localMessage = {
      kind = "user",
      direction = "out",
      text = "legacy group text",
      guid = "Player-local",
      playerName = "SameName-Realm",
    }
    local remoteMessage = {
      kind = "user",
      direction = "in",
      text = "legacy group text",
      guid = "Player-remote",
      playerName = "SameName-Realm",
    }
    local duplicateAuthor = {
      kind = "user",
      direction = "in",
      text = "legacy group text",
      guid = "Player-duplicate",
      playerName = "SameName-Realm",
    }
    addConversation(state, "group-legacy", { localMessage, remoteMessage, duplicateAuthor })

    local function operationFor(operation, target)
      return assert(
        Protocol.Decode(
          Protocol.EncodeGroupReaction(
            operation,
            "heart",
            nil,
            target.text,
            Protocol.BuildGroupFallback("heart", operation, target.text),
            target.guid,
            target.playerName
          )
        )
      )
    end

    local changed, target = MessageReactions.ApplyOperation(state, "group-legacy", operationFor("set", localMessage), "Actor-Realm", nil, 100)
    assert(changed == true and target == localMessage, "nil-wire group set must target outgoing original author")
    assert(remoteMessage.reaction == nil and duplicateAuthor.reaction == nil, "nil-wire group set must isolate duplicate author names")

    changed, target = MessageReactions.ApplyOperation(state, "group-legacy", operationFor("set", remoteMessage), "Actor-Realm", nil, 101)
    assert(changed == true and target == remoteMessage, "nil-wire group set must target incoming original author")

    changed, target = MessageReactions.ApplyOperation(state, "group-legacy", operationFor("remove", remoteMessage), "Actor-Realm", nil, 102)
    assert(changed == true and target == remoteMessage and remoteMessage.reaction == nil, "nil-wire group remove must clear incoming target")
  end
  -- Expired correlation work releases sender aliases.
  do
    local state = newState()
    MessageReactions.RecordIdentity(state, "bngame:7", "conversation", {
      type = "identity",
      wireId = "wire-7",
      sourceFingerprint = "fingerprint",
    }, 100)
    MessageReactions.AssociateSenderAlias(state, "bngame:7", "bn:42")
    assert(MessageReactions.ResolveSenderAlias(state, "bngame:7") == "bn:42", "active correlation must retain sender alias")

    MessageReactions.Expire(state, 115)

    assert(MessageReactions.ResolveSenderAlias(state, "bngame:7") == "bngame:7", "expired correlation must release sender alias")
  end
end
