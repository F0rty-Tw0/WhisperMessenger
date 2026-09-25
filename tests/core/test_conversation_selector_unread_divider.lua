local ConversationSelector = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ConversationSelector")
local Store = require("WhisperMessenger.Model.ConversationStore")

local function incoming(text)
  return { kind = "user", direction = "in", text = text }
end

local function build()
  local runtime = { store = Store.New({}) }
  local selector = ConversationSelector.Create({
    runtime = runtime,
    characterState = {},
    markConversationRead = Store.MarkRead,
    presenceCache = { RefreshPresence = function() end },
    requestAvailability = function() end,
  })
  return selector, runtime
end

local function addConversation(runtime, key, messages, unreadCount)
  local conversation = Store.EnsureConversation(runtime.store, key)
  conversation.messages = messages
  conversation.unreadCount = unreadCount
  return conversation
end

return function()
  -- test_opening_unread_conversation_marks_first_unread_message
  do
    local selector, runtime = build()
    local messages = {
      incoming("old"),
      { kind = "user", direction = "out", text = "reply" },
      incoming("new 1"),
      { kind = "channel_context", direction = "in", text = "trade post" },
      incoming("new 2"),
    }
    addConversation(runtime, "A", messages, 2)
    selector.selectConversation("A")
    assert(runtime.unreadDivider ~= nil, "unread conversation gets a divider")
    assert(runtime.unreadDivider.conversationKey == "A", "divider belongs to the opened conversation")
    assert(runtime.unreadDivider.message == messages[3], "divider sits before the first unread incoming message")
    assert(runtime.store.conversations.A.unreadCount == 0, "conversation still marked read")
  end

  -- test_opening_conversation_without_unread_has_no_divider
  do
    local selector, runtime = build()
    addConversation(runtime, "A", { incoming("hi") }, 2)
    addConversation(runtime, "B", { incoming("hey") }, 0)
    selector.selectConversation("A")
    selector.selectConversation("B")
    assert(runtime.unreadDivider == nil, "switching to a read conversation drops the divider")
  end

  -- test_reselecting_same_conversation_keeps_divider
  do
    local selector, runtime = build()
    local messages = { incoming("a"), incoming("b") }
    addConversation(runtime, "A", messages, 1)
    selector.selectConversation("A")
    selector.selectConversation("A")
    assert(runtime.unreadDivider and runtime.unreadDivider.message == messages[2], "divider stays while the conversation stays selected")
  end

  -- test_more_unread_than_stored_messages_marks_oldest_incoming
  do
    local selector, runtime = build()
    local messages = { { kind = "user", direction = "out", text = "me" }, incoming("only") }
    addConversation(runtime, "A", messages, 5)
    selector.selectConversation("A")
    assert(runtime.unreadDivider.message == messages[2], "divider falls back to the oldest incoming message")
  end

  -- test_unread_without_any_stored_incoming_message_has_no_divider
  do
    local selector, runtime = build()
    addConversation(runtime, "A", { { kind = "user", direction = "out", text = "me" } }, 1)
    selector.selectConversation("A")
    assert(runtime.unreadDivider == nil, "nothing to mark -> no divider")
  end
end
