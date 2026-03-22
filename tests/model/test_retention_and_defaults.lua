local Retention = require("WhisperMessenger.Model.Retention")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local Store = require("WhisperMessenger.Model.ConversationStore")

return function()
  -- TEST 1: TrimMessages is O(n) — correct result after bulk trim
  local messages = {}
  for i = 1, 500 do
    messages[i] = { id = tostring(i), text = "msg " .. i }
  end
  Retention.TrimMessages(messages, 100)
  assert(#messages == 100, "expected 100 messages after trim, got " .. #messages)
  assert(messages[1].id == "401", "expected first message to be id 401, got " .. messages[1].id)
  assert(messages[100].id == "500", "expected last message to be id 500, got " .. messages[100].id)

  -- Verify no nil holes in trimmed array
  for i = 1, 100 do
    assert(messages[i] ~= nil, "nil hole at index " .. i)
  end
  -- Verify no leftover entries beyond the trimmed length
  assert(messages[101] == nil, "expected no entry at index 101")

  -- TEST 2: TrimMessages single excess
  local msgs2 = { { id = "a" }, { id = "b" }, { id = "c" } }
  Retention.TrimMessages(msgs2, 2)
  assert(#msgs2 == 2, "expected 2 messages, got " .. #msgs2)
  assert(msgs2[1].id == "b", "expected first to be b, got " .. msgs2[1].id)
  assert(msgs2[2].id == "c", "expected second to be c, got " .. msgs2[2].id)

  -- TEST 3: TrimMessages no-op when under limit
  local msgs3 = { { id = "x" } }
  Retention.TrimMessages(msgs3, 10)
  assert(#msgs3 == 1, "expected 1 message, got " .. #msgs3)

  -- TEST 4: Default maxMessagesPerConversation is applied when not specified
  local runtime = RuntimeFactory.CreateRuntimeState(
    { conversations = {} },
    { activeConversationKey = nil },
    "testplayer",
    {} -- no maxMessagesPerConversation specified
  )
  assert(
    type(runtime.store.config.maxMessagesPerConversation) == "number",
    "expected default maxMessagesPerConversation to be set"
  )
  assert(runtime.store.config.maxMessagesPerConversation > 0, "expected positive default maxMessagesPerConversation")

  -- TEST 5: Explicit maxMessagesPerConversation overrides default
  local runtime2 = RuntimeFactory.CreateRuntimeState(
    { conversations = {} },
    { activeConversationKey = nil },
    "testplayer",
    { maxMessagesPerConversation = 50 }
  )
  assert(
    runtime2.store.config.maxMessagesPerConversation == 50,
    "expected explicit maxMessagesPerConversation=50, got "
      .. tostring(runtime2.store.config.maxMessagesPerConversation)
  )

  -- TEST 6: Messages are actually trimmed with the default cap
  local key = "wow::WOW::test-contact"
  local cap = runtime.store.config.maxMessagesPerConversation
  for i = 1, cap + 10 do
    Store.AppendIncoming(runtime.store, key, {
      id = tostring(i),
      direction = "in",
      kind = "user",
      text = "msg " .. i,
      sentAt = i,
    }, false)
  end
  local conv = runtime.store.conversations[key]
  assert(#conv.messages == cap, "expected messages capped at " .. cap .. ", got " .. #conv.messages)
end
