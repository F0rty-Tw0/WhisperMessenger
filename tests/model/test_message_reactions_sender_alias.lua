local SenderAlias = require("WhisperMessenger.Model.MessageReactions.SenderAlias")
local PendingQueue = require("WhisperMessenger.Model.MessageReactions.PendingQueue")

return function()
  -- test_resolve_returns_key_when_no_alias
  do
    assert(SenderAlias.Resolve({}, "bn::1") == "bn::1", "unknown sender must resolve to itself")
    assert(SenderAlias.Resolve(nil, "bn::1") == "bn::1", "missing state must resolve to itself")
  end

  -- test_associate_merges_alias_queue_in_recorded_order
  do
    local state = {}
    local runtime = PendingQueue.RuntimeState(state)
    PendingQueue.Record(state, runtime, runtime.operations, "canonical", { recordedAt = 5 })
    PendingQueue.Record(state, runtime, runtime.operations, "alias", { recordedAt = 2 })
    assert(SenderAlias.Associate(state, "alias", "canonical") == true, "first association must succeed")
    assert(SenderAlias.Resolve(state, "alias") == "canonical", "alias must resolve to canonical key")
    local queue = runtime.operations.canonical
    assert(runtime.operations.alias == nil, "alias queue must be folded away")
    assert(#queue == 2 and queue[1].recordedAt == 2 and queue[2].recordedAt == 5, "merged queue must be time-ordered")
  end

  -- test_associate_refuses_conflicting_or_self_alias
  do
    local state = {}
    assert(SenderAlias.Associate(state, "alias", "one") == true, "first association must succeed")
    assert(SenderAlias.Associate(state, "alias", "two") == false, "conflicting association must fail")
    assert(SenderAlias.Associate(state, "same", "same") == false, "self alias must fail")
  end

  -- test_move_queues_folds_one_sender_into_another_in_recorded_order
  do
    local state = {}
    local runtime = PendingQueue.RuntimeState(state)
    PendingQueue.Record(state, runtime, runtime.identityMetadata, "to", { recordedAt = 5 })
    PendingQueue.Record(state, runtime, runtime.identityMetadata, "from", { recordedAt = 2 })
    SenderAlias.MoveQueues(state, "from", "to")
    local queue = runtime.identityMetadata.to
    assert(runtime.identityMetadata.from == nil, "the old sender's queue must be folded away")
    assert(#queue == 2 and queue[1].recordedAt == 2 and queue[2].recordedAt == 5, "merged queue must be time-ordered")
  end

  -- test_move_queues_records_no_alias
  do
    local state = {}
    local runtime = PendingQueue.RuntimeState(state)
    PendingQueue.Record(state, runtime, runtime.operations, "from", { recordedAt = 2 })
    SenderAlias.MoveQueues(state, "from", "to")
    assert(SenderAlias.Resolve(state, "from") == "from", "a moved sender must not become an alias")
  end

  -- test_move_queues_keeps_the_sender_cap
  do
    local state = {}
    local runtime = PendingQueue.RuntimeState(state)
    for index = 1, 32 do
      PendingQueue.Record(state, runtime, runtime.operations, "to", { recordedAt = 10 + index })
    end
    PendingQueue.Record(state, runtime, runtime.operations, "from", { recordedAt = 1 })
    SenderAlias.MoveQueues(state, "from", "to")
    local queue = runtime.operations.to
    assert(#queue == 32 and queue[1].recordedAt == 11, "the oldest entry must be evicted past the cap, got " .. #queue)
  end

  -- test_move_queues_without_waiting_reactions_is_a_no_op
  do
    local state = {}
    SenderAlias.MoveQueues(state, "from", "to")
    assert(state.messageReactionRuntime == nil, "nothing is created when nothing waits")
  end
end
