local Store = require("WhisperMessenger.Model.ConversationStore")

local KEYS = { "me::WOW::jaina", "me::PARTY::party", "channel::me::trade" }

local function build()
  local state = Store.New({ maxMessagesPerConversation = 10 })
  for _, key in ipairs(KEYS) do
    Store.EnsureConversation(state, key)
  end
  return state
end

return function()
  -- test_remove_all_fires_removed_hook_for_each_conversation
  do
    local state = build()
    local removed = {}
    state.onConversationRemoved = function(key, conversation, reason)
      assert(type(conversation) == "table", "the hook gets the removed conversation")
      removed[key] = reason
    end

    Store.RemoveAll(state)

    assert(next(state.conversations) == nil, "every conversation is gone")
    for _, key in ipairs(KEYS) do
      assert(removed[key] == "explicit", key .. " goes through the removal hook as an explicit removal")
    end
  end

  -- test_remove_all_keeps_the_saved_conversations_table
  do
    local state = build()
    local conversations = state.conversations
    Store.RemoveAll(state)
    assert(state.conversations == conversations, "saved variables point at this table, so it is emptied in place")
  end

  -- test_remove_all_drops_message_retention_boundaries
  do
    local state = build()
    state.messageRetentionAt = { [KEYS[1]] = 500 }
    Store.RemoveAll(state)
    assert(state.messageRetentionAt[KEYS[1]] == nil, "a removed conversation has no retention boundary")
  end

  -- test_remove_all_on_empty_store_fires_no_hook
  do
    local state = Store.New({ maxMessagesPerConversation = 10 })
    state.onConversationRemoved = function()
      error("nothing to remove")
    end
    Store.RemoveAll(state)
  end
end
