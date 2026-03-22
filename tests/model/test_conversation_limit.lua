local Store = require("WhisperMessenger.Model.ConversationStore")

return function()
  -- TEST 1: Conversations are pruned when exceeding maxConversations
  local state = Store.New({
    maxMessagesPerConversation = 50,
    maxConversations = 5,
  })

  -- Create 5 conversations with increasing activity times
  for i = 1, 5 do
    Store.AppendIncoming(state, "conv-" .. i, {
      id = tostring(i),
      direction = "in",
      kind = "user",
      text = "msg " .. i,
      sentAt = i * 100,
    }, false)
  end

  -- Count conversations
  local function countConversations()
    local count = 0
    for _ in pairs(state.conversations) do
      count = count + 1
    end
    return count
  end

  assert(countConversations() == 5, "expected 5 conversations, got " .. countConversations())

  -- Add a 6th conversation — should evict the oldest (conv-1, sentAt=100)
  Store.AppendIncoming(state, "conv-6", {
    id = "6",
    direction = "in",
    kind = "user",
    text = "msg 6",
    sentAt = 600,
  }, false)

  assert(countConversations() == 5, "expected 5 after limit, got " .. countConversations())
  assert(state.conversations["conv-1"] == nil, "expected oldest conversation conv-1 to be pruned")
  assert(state.conversations["conv-6"] ~= nil, "expected new conversation conv-6 to exist")

  -- TEST 2: Existing conversation update does NOT trigger eviction
  Store.AppendIncoming(state, "conv-2", {
    id = "7",
    direction = "in",
    kind = "user",
    text = "follow-up",
    sentAt = 700,
  }, false)

  assert(countConversations() == 5, "expected 5 after update, got " .. countConversations())
  assert(state.conversations["conv-2"] ~= nil, "expected conv-2 to still exist")

  -- TEST 3: Adding another new conversation evicts the next oldest
  Store.AppendIncoming(state, "conv-7", {
    id = "8",
    direction = "in",
    kind = "user",
    text = "msg 7",
    sentAt = 800,
  }, false)

  assert(countConversations() == 5, "expected 5 after second eviction, got " .. countConversations())
  assert(state.conversations["conv-3"] == nil, "expected conv-3 to be pruned (next oldest)")
  assert(state.conversations["conv-7"] ~= nil, "expected conv-7 to exist")

  -- TEST 4: No maxConversations = no limit (default behavior)
  local unlimitedState = Store.New({ maxMessagesPerConversation = 50 })
  for i = 1, 10 do
    Store.AppendIncoming(unlimitedState, "u-" .. i, {
      id = tostring(i),
      direction = "in",
      kind = "user",
      text = "msg",
      sentAt = i,
    }, false)
  end

  local unlimitedCount = 0
  for _ in pairs(unlimitedState.conversations) do
    unlimitedCount = unlimitedCount + 1
  end
  assert(unlimitedCount == 10, "expected 10 without limit, got " .. unlimitedCount)
end
