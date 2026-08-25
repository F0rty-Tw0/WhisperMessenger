local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local MessageReactions = require("WhisperMessenger.Model.MessageReactions")

local function newState(nowRef)
  return {
    store = { conversations = {} },
    now = function()
      return nowRef.value
    end,
  }
end

local function pendingCount(state, senderKey)
  local runtime = state.messageReactionRuntime or {}
  local count = 0
  for _, queues in ipairs({
    runtime.identityMetadata or {},
    runtime.identityMessages or {},
    runtime.operations or {},
    runtime.controls or {},
  }) do
    count = count + #(queues[senderKey] or {})
  end
  return count
end

return function()
  local savedTimer = _G.C_Timer

  -- Aggregate pending state is capped per sender across all queue types.
  do
    local scheduled = {}
    _G.C_Timer = {
      After = function(delay, callback)
        scheduled[#scheduled + 1] = { delay = delay, callback = callback }
      end,
    }
    local now = { value = 100 }
    local state = newState(now)
    for index = 1, 40 do
      MessageReactions.RecordIdentity(state, "Flooder", "conv", {
        type = "identity",
        wireId = "wire" .. tostring(index),
        sourceFingerprint = Protocol.Fingerprint("text" .. tostring(index)),
      }, now.value)
    end
    assert(pendingCount(state, "Flooder") == 32, "aggregate pending entries should cap at 32 per sender")
    assert(#scheduled == 1, "pending flood should schedule only one cleanup timer")
  end

  -- Evicting the oldest readable control degrades it instead of losing text.
  do
    local scheduled = {}
    _G.C_Timer = {
      After = function(delay, callback)
        scheduled[#scheduled + 1] = { delay = delay, callback = callback }
      end,
    }
    local now = { value = 200 }
    local state = newState(now)
    local degraded
    local fallback = Protocol.BuildFallback("heart", "set", "oldest")
    MessageReactions.ConsumeIncomingControl(
      state,
      "Flooder",
      "conv",
      "Flooder",
      {
        kind = "user",
        direction = "in",
        text = fallback,
        sentAt = now.value,
      },
      "out",
      now.value,
      function(message)
        degraded = message
      end
    )
    for index = 1, 32 do
      MessageReactions.RecordIdentity(state, "Flooder", "conv", {
        type = "identity",
        wireId = "meta" .. tostring(index),
        sourceFingerprint = Protocol.Fingerprint("meta" .. tostring(index)),
      }, now.value)
    end
    assert(degraded and degraded.text == fallback, "evicted readable control should degrade through its append callback")
    assert(pendingCount(state, "Flooder") == 32, "eviction should retain only newest 32 aggregate entries")
    assert(#scheduled == 1, "eviction flood should retain one cleanup timer")
  end

  -- One timer tracks earliest deadline and reschedules for the next entry.
  do
    local scheduled = {}
    _G.C_Timer = {
      After = function(delay, callback)
        scheduled[#scheduled + 1] = { delay = delay, callback = callback }
      end,
    }
    local now = { value = 300 }
    local state = newState(now)
    local degraded = {}
    local function stage(source)
      local fallback = Protocol.BuildFallback("sad", "set", source)
      MessageReactions.ConsumeIncomingControl(
        state,
        "Flooder",
        "conv",
        "Flooder",
        {
          kind = "user",
          direction = "in",
          text = fallback,
          sentAt = now.value,
        },
        "out",
        now.value,
        function(message)
          degraded[#degraded + 1] = message.text
        end
      )
    end
    stage("first")
    now.value = 305
    stage("second")
    assert(#scheduled == 1 and scheduled[1].delay == 15, "two pending entries should share earliest cleanup timer")
    now.value = 315
    scheduled[1].callback()
    assert(#degraded == 1, "earliest timer should degrade only expired entry")
    assert(#scheduled == 2 and scheduled[2].delay == 5, "cleanup should reschedule once for next earliest deadline")
    now.value = 320
    scheduled[2].callback()
    assert(#degraded == 2, "rescheduled timer should degrade next entry")
  end

  -- Modern wire ID lookup rejects forged source fingerprints.
  do
    local now = { value = 400 }
    local state = newState(now)
    local target = { kind = "user", direction = "out", text = "authentic source", wireId = "modern-wire", sentAt = 390 }
    state.store.conversations.conv = { conversationKey = "conv", messages = { target } }
    local changed, matched = MessageReactions.ApplyOperation(state, "conv", {
      type = "reaction",
      operation = "set",
      key = "angry",
      wireId = "modern-wire",
      sourceFingerprint = Protocol.Fingerprint("forged source"),
      fallbackFingerprint = Protocol.Fingerprint("fallback"),
    }, "Attacker", "out", now.value)
    assert(changed == false and matched == nil, "wire ID with mismatched source fingerprint must be rejected")
    assert(target.reaction == nil, "forged modern target metadata must not mutate reaction state")
  end

  _G.C_Timer = savedTimer
end
