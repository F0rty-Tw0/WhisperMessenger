local PendingQueue = require("WhisperMessenger.Model.MessageReactions.PendingQueue")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")

local TTL = Protocol.PAIRING_TTL_SECONDS

local function record(state, field, senderKey, entry)
  local runtime = PendingQueue.RuntimeState(state)
  PendingQueue.Record(state, runtime, runtime[field], senderKey, entry)
  return runtime
end

return function()
  local savedTimer = _G.C_Timer
  local scheduled = {}
  _G.C_Timer = {
    After = function(delay, callback)
      table.insert(scheduled, { delay = delay, callback = callback })
    end,
  }

  -- test_record_caps_sender_queue_and_degrades_evicted_control
  do
    local state = {}
    local degraded = {}
    local first = { text = "first" }
    record(state, "controls", "sender", {
      recordedAt = 0,
      message = first,
      onDegrade = function(message)
        table.insert(degraded, message)
      end,
    })
    local runtime
    for index = 1, 32 do
      runtime = record(state, "operations", "sender", { recordedAt = index })
    end
    assert(runtime.controls.sender == nil, "oldest control must be evicted past the cap")
    assert(#runtime.operations.sender == 32, "cap must keep 32 entries")
    assert(degraded[1] == first, "evicted control must degrade its message")
  end

  -- test_record_schedules_cleanup_at_entry_deadline
  do
    scheduled = {}
    local state = {
      now = function()
        return 100
      end,
    }
    record(state, "identityMessages", "sender", { recordedAt = 100 })
    assert(#scheduled == 1 and scheduled[1].delay == TTL, "cleanup must fire one TTL after the entry")
    assert(state.messageReactionCleanupDueAt == 100 + TTL, "cleanup deadline must be stored")
  end

  -- test_expire_drops_entries_past_ttl_and_prunes_aliases
  do
    local state = {}
    local runtime = record(state, "identityMetadata", "sender", { recordedAt = 0 })
    record(state, "identityMetadata", "sender", { recordedAt = 10 })
    runtime.senderAliases.alias = "sender"
    PendingQueue.Expire(state, TTL)
    assert(#runtime.identityMetadata.sender == 1, "only the expired entry must go")
    assert(runtime.senderAliases.alias == "sender", "alias with pending entries must stay")
    PendingQueue.Expire(state, 10 + TTL)
    assert(runtime.identityMetadata.sender == nil, "empty sender queue must be removed")
    assert(runtime.senderAliases.alias == nil, "alias without pending entries must be pruned")
  end

  -- test_clear_conversation_removes_only_that_conversation
  do
    local state = {}
    local runtime = record(state, "operations", "sender", { recordedAt = 0, conversationKey = "a" })
    record(state, "operations", "sender", { recordedAt = 0, conversationKey = "b" })
    PendingQueue.ClearConversation(state, "a")
    assert(#runtime.operations.sender == 1 and runtime.operations.sender[1].conversationKey == "b", "other conversation must stay")
  end

  -- test_flush_controls_degrades_and_drops_runtime
  do
    local state = {}
    local degraded = 0
    record(state, "controls", "sender", {
      recordedAt = 0,
      onDegrade = function()
        degraded = degraded + 1
      end,
    })
    PendingQueue.FlushControls(state)
    assert(degraded == 1, "flushed control must degrade")
    assert(state.messageReactionRuntime == nil and state.messageReactionCleanupDueAt == nil, "flush must drop runtime")
  end

  _G.C_Timer = savedTimer
end
