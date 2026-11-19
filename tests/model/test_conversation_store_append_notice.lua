local Store = require("WhisperMessenger.Model.ConversationStore")

return function()
  local function notice(sentAt)
    return { id = "n" .. sentAt, kind = "system", direction = "in", text = "Left party", sentAt = sentAt }
  end

  -- test_append_notice_keeps_last_activity_and_updates_preview
  do
    local state = Store.New({})
    Store.AppendIncoming(state, "party::me", { id = "m1", kind = "user", direction = "in", text = "hi", sentAt = 100 }, true)

    local conversation = Store.AppendNotice(state, "party::me", notice(500))

    assert(conversation == state.conversations["party::me"], "returns the conversation")
    assert(#conversation.messages == 2, "the notice is stored")
    assert(conversation.lastActivityAt == 100, "a notice is not activity, got " .. tostring(conversation.lastActivityAt))
    assert(conversation.lastPreview == "Left party", "the notice becomes the row preview")
    assert(conversation.unreadCount == 0, "a notice is not unread")
  end

  -- test_append_notice_ignores_missing_conversation
  do
    local state = Store.New({})

    assert(Store.AppendNotice(state, "party::me", notice(500)) == nil, "nothing to append to")
    assert(state.conversations["party::me"] == nil, "a notice never creates a conversation")
  end
end
