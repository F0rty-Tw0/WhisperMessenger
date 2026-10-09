local Store = require("WhisperMessenger.Model.ConversationStore")

local KEY = "wow::WOW::jaina-proudmoore"

local function incoming(id, sentAt, lineID)
  return { id = id, direction = "in", kind = "user", text = "in " .. id, sentAt = sentAt, lineID = lineID, playerName = "Jaina-Proudmoore" }
end

local function outgoing(id, sentAt, lineID)
  return { id = id, direction = "out", kind = "user", text = "out " .. id, sentAt = sentAt, lineID = lineID, playerName = "Arthas" }
end

local function storeWithIncomingAt(sentAt, lineID)
  local state = Store.New({})
  Store.AppendIncoming(state, KEY, incoming("in-1", sentAt, lineID), false)
  return state
end

return function()
  -- test_outgoing_inserted_before_newer_message

  do
    local state = storeWithIncomingAt(200, 20)
    Store.InsertOutgoingChronological(state, KEY, outgoing("out-1", 150, 15))
    local messages = state.conversations[KEY].messages
    assert(#messages == 2, "expected 2 messages, got " .. #messages)
    assert(messages[1].id == "out-1" and messages[2].id == "in-1", "older outgoing must land before the newer incoming")
  end

  -- test_older_outgoing_keeps_preview_and_last_activity

  do
    local state = storeWithIncomingAt(200, 20)
    Store.InsertOutgoingChronological(state, KEY, outgoing("out-1", 150, 15))
    local conversation = state.conversations[KEY]
    assert(conversation.lastActivityAt == 200, "lastActivityAt must stay 200, got " .. tostring(conversation.lastActivityAt))
    assert(conversation.lastPreview == "in in-1", "preview must stay on the newer incoming, got " .. tostring(conversation.lastPreview))
  end

  -- test_newest_outgoing_updates_activity

  do
    local state = storeWithIncomingAt(200, 20)
    Store.InsertOutgoingChronological(state, KEY, outgoing("out-1", 250, 25))
    local conversation = state.conversations[KEY]
    assert(conversation.lastActivityAt == 250, "newest outgoing must move lastActivityAt to 250")
    assert(conversation.lastPreview == "out out-1", "newest outgoing must become the preview")
    assert(conversation.messages[2].id == "out-1", "newest outgoing must be last")
  end

  -- test_outgoing_insert_clears_request

  do
    local state = storeWithIncomingAt(200, 20)
    state.conversations[KEY].request = { state = "pending" }
    Store.InsertOutgoingChronological(state, KEY, outgoing("out-1", 150, 15))
    assert(state.conversations[KEY].request == nil, "writing to someone must accept their request")
  end

  -- test_outgoing_insert_leaves_unread_count

  do
    local state = storeWithIncomingAt(200, 20)
    local before = state.conversations[KEY].unreadCount
    Store.InsertOutgoingChronological(state, KEY, outgoing("out-1", 250, 25))
    assert(before == 1, "setup: one unread incoming expected")
    assert(state.conversations[KEY].unreadCount == before, "outgoing insert must not change unreadCount")
  end

  -- test_same_sent_at_orders_by_line_id

  do
    local state = storeWithIncomingAt(200, 20)
    Store.InsertOutgoingChronological(state, KEY, outgoing("out-1", 200, 19))
    local messages = state.conversations[KEY].messages
    assert(messages[1].id == "out-1" and messages[2].id == "in-1", "lower lineID at the same sentAt must land first")
  end
end
