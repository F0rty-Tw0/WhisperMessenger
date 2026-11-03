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
end
