local GroupSendPending = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPending")

return function()
  -- test_record_queues_entry_under_conversation_key

  do
    local runtime = {}
    local entry = { text = "hi", createdAt = 100 }
    assert(GroupSendPending.Record(runtime, "party::me", entry, 100) == entry, "record returns the entry")
    assert(runtime.pendingGroupOutgoing["party::me"][1] == entry, "the entry is queued under its conversation")
  end

  -- test_record_ignores_empty_conversation_key

  do
    local runtime = {}
    assert(GroupSendPending.Record(runtime, "", { createdAt = 1 }, 1) == nil, "an empty key records nothing")
    assert(runtime.pendingGroupOutgoing == nil, "no queue table is created for an empty key")
  end

  -- test_record_prunes_expired_entries_in_every_queue

  do
    local stale = { createdAt = 100 }
    local runtime = { pendingGroupOutgoing = { ["raid::me"] = { stale } } }
    GroupSendPending.Record(runtime, "party::me", { createdAt = 116 }, 116)
    assert(runtime.pendingGroupOutgoing["raid::me"] == nil, "an entry older than 15 seconds is dropped with its empty queue")
    assert(#runtime.pendingGroupOutgoing["party::me"] == 1, "the new entry is kept")
  end

  -- test_prune_keeps_entries_inside_the_window

  do
    local fresh = { createdAt = 100 }
    local runtime = { pendingGroupOutgoing = { ["party::me"] = { fresh } } }
    GroupSendPending.Prune(runtime, "party::me", 115)
    assert(runtime.pendingGroupOutgoing["party::me"][1] == fresh, "an entry exactly 15 seconds old still waits for its echo")
  end

  -- test_discard_removes_only_the_given_entry

  do
    local first, second = { createdAt = 1 }, { createdAt = 2 }
    local runtime = { pendingGroupOutgoing = { ["party::me"] = { first, second } } }
    GroupSendPending.Discard(runtime, "party::me", first)
    local queue = runtime.pendingGroupOutgoing["party::me"]
    assert(#queue == 1 and queue[1] == second, "the other entry stays queued")
    GroupSendPending.Discard(runtime, "party::me", second)
    assert(runtime.pendingGroupOutgoing["party::me"] == nil, "the emptied queue is removed")
  end

  -- test_now_falls_back_to_zero_when_the_clock_fails

  do
    assert(GroupSendPending.Now({
      now = function()
        return 42
      end,
    }) == 42, "the runtime clock is used")
    assert(GroupSendPending.Now({
      now = function()
        error("boom")
      end,
    }) == 0, "a failing clock reads as 0")
    assert(GroupSendPending.Now({}) == 0, "a missing clock reads as 0")
  end
end
