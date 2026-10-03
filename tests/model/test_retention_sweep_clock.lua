local Store = require("WhisperMessenger.Model.ConversationStore")
local StoreRetention = require("WhisperMessenger.Model.ConversationStore.StoreRetention")

-- The throttled cross-conversation sweep must not stall when the clock
-- jumps backwards (the last sweep time would otherwise sit in the future).
return function()
  -- test_append_sweeps_when_clock_went_backwards
  do
    local clock = 1000
    local state = Store.New({ maxMessagesPerConversation = 10, maxConversations = 10, messageMaxAge = 100, conversationMaxAge = 100 }, function()
      return clock
    end)
    local calls = 0
    local original = StoreRetention.IsExpired
    rawset(StoreRetention, "IsExpired", function(...)
      calls = calls + 1
      return original(...)
    end)
    for i = 1, 3 do
      state.conversations["key::" .. i] = { messages = {}, lastActivityAt = 990, unreadCount = 0 }
    end
    local function append(id)
      Store.AppendIncoming(state, "key::active", { id = id, direction = "in", kind = "user", text = id, sentAt = clock }, false)
    end
    append("a")
    local afterFirst = calls
    clock = 900
    append("b")
    rawset(StoreRetention, "IsExpired", original)
    assert(calls > afterFirst, "an append after the clock went backwards must sweep")
    assert(state.lastRetentionSweepAt == 900, "the sweep time follows the new clock, got " .. tostring(state.lastRetentionSweepAt))
  end
end
