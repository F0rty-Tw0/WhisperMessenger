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

  -- TEST 5: Eviction never removes a pinned conversation — pinning exempts a
  -- conversation from every other retention path, so the cap must skip it too.
  local pinnedState = Store.New({ maxMessagesPerConversation = 50, maxConversations = 3 })
  for i = 1, 3 do
    Store.AppendIncoming(pinnedState, "p-" .. i, {
      id = tostring(i),
      direction = "in",
      kind = "user",
      text = "msg " .. i,
      sentAt = i * 100,
    }, false)
  end
  -- p-1 is the oldest but pinned; p-2 becomes the eviction candidate.
  pinnedState.conversations["p-1"].pinned = true

  Store.AppendIncoming(pinnedState, "p-4", {
    id = "4",
    direction = "in",
    kind = "user",
    text = "msg 4",
    sentAt = 400,
  }, false)

  assert(pinnedState.conversations["p-1"] ~= nil, "pinned conversation must survive eviction")
  assert(pinnedState.conversations["p-2"] == nil, "oldest unpinned conversation is evicted instead")
  assert(pinnedState.conversations["p-4"] ~= nil, "new conversation exists")

  -- TEST 6: all pinned conversations soft-overflow rather than dropping a new incoming thread.
  local allPinnedIncoming = Store.New({ maxMessagesPerConversation = 50, maxConversations = 3 })
  for i = 1, 3 do
    Store.AppendIncoming(allPinnedIncoming, "in-" .. i, {
      id = tostring(i),
      direction = "in",
      kind = "user",
      text = "pinned " .. i,
      sentAt = i,
    }, false)
    Store.Pin(allPinnedIncoming, "in-" .. i)
  end
  Store.AppendIncoming(allPinnedIncoming, "new-incoming", {
    id = "new",
    direction = "in",
    kind = "user",
    text = "must survive",
    sentAt = 4,
  }, false)
  assert(allPinnedIncoming.conversations["new-incoming"] ~= nil, "all-pinned cap must retain a new incoming conversation")
  local incomingCount = 0
  for _ in pairs(allPinnedIncoming.conversations) do
    incomingCount = incomingCount + 1
  end
  assert(incomingCount == 4, "all-pinned cap should soft-overflow to four conversations")

  -- TEST 7: the same protection applies to a new outgoing thread.
  local allPinnedOutgoing = Store.New({ maxMessagesPerConversation = 50, maxConversations = 3 })
  for i = 1, 3 do
    Store.AppendIncoming(allPinnedOutgoing, "out-" .. i, {
      id = tostring(i),
      direction = "in",
      kind = "user",
      text = "pinned " .. i,
      sentAt = i,
    }, false)
    Store.Pin(allPinnedOutgoing, "out-" .. i)
  end
  Store.AppendOutgoing(allPinnedOutgoing, "new-outgoing", {
    id = "new",
    direction = "out",
    kind = "user",
    text = "must survive",
    sentAt = 4,
  })
  assert(allPinnedOutgoing.conversations["new-outgoing"] ~= nil, "all-pinned cap must retain a new outgoing conversation")

  -- TEST 8: equally old eligible records evict by key, not table iteration order.
  local deterministicState = Store.New({ maxMessagesPerConversation = 50, maxConversations = 3 })
  for _, key in ipairs({ "a", "b", "c" }) do
    Store.AppendIncoming(deterministicState, key, {
      id = key,
      direction = "in",
      kind = "user",
      text = key,
      sentAt = 1,
    }, false)
  end
  Store.Pin(deterministicState, "c")
  Store.AppendIncoming(deterministicState, "new", {
    id = "new",
    direction = "in",
    kind = "user",
    text = "new",
    sentAt = 2,
  }, false)
  assert(deterministicState.conversations.a == nil, "lexically first equally-old eligible conversation should evict")
  assert(
    deterministicState.conversations.b ~= nil and deterministicState.conversations.c ~= nil,
    "other existing conversations should survive deterministic eviction"
  )
  assert(deterministicState.conversations.new ~= nil, "protected new conversation should survive deterministic eviction")

  -- TEST 9: a soft overflow is persisted until a user deliberately unpins.
  local reloadedState = Store.New({ maxMessagesPerConversation = 50, maxConversations = 3 })
  reloadedState.conversations = allPinnedIncoming.conversations
  local reloadedCount = 0
  for _ in pairs(reloadedState.conversations) do
    reloadedCount = reloadedCount + 1
  end
  assert(reloadedCount == 4, "reload must retain an all-pinned soft overflow")

  Store.Unpin(allPinnedIncoming, "new-incoming")
  assert(allPinnedIncoming.conversations["new-incoming"] == nil, "unpinning the only eligible overflow conversation should converge to the cap")
end
