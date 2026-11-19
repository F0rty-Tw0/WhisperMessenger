local ConversationMerge = require("WhisperMessenger.Model.ConversationMerge")

-- Merging two records of one chat shows the merged thread's last line as the
-- row preview, even a status line newer than either record's activity.
return function()
  local function line(id, kind, text, sentAt, lineID)
    return { id = id, kind = kind, direction = "in", text = text, sentAt = sentAt, lineID = lineID }
  end

  -- test_merged_preview_is_the_merged_threads_last_line
  do
    local conversations = {
      old = { messages = { line("m2", "user", "brb", 200, 2) }, lastActivityAt = 200, lastActivityLineID = 2, lastPreview = "brb" },
      new = {
        messages = { line("m1", "user", "hi", 100, 1), line("s1", "system", "Jaina is offline.", 300) },
        lastActivityAt = 100,
        lastActivityLineID = 1,
        lastPreview = "Jaina is offline.",
      },
    }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local merged = conversations.new
    assert(merged.lastActivityAt == 200, "activity is the newest real line, got " .. tostring(merged.lastActivityAt))
    assert(merged.lastPreview == "Jaina is offline.", "preview is the merged thread's last line, got " .. tostring(merged.lastPreview))
  end

  -- test_merged_preview_without_messages_comes_from_the_newer_activity
  do
    local conversations = {
      old = { messages = {}, lastActivityAt = 200, lastPreview = "newer" },
      new = { messages = {}, lastActivityAt = 100, lastPreview = "older" },
    }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    assert(conversations.new.lastPreview == "newer", "no messages: the newer record's preview, got " .. tostring(conversations.new.lastPreview))
  end

  -- test_merged_preview_keeps_a_line_kept_outside_the_thread_that_is_newer
  do
    local conversations = {
      old = { messages = { line("m2", "user", "brb", 200, 2) }, lastActivityAt = 500, lastActivityLineID = 5, lastPreview = "recorded" },
      new = { messages = { line("m1", "user", "hi", 100, 1) }, lastActivityAt = 100, lastActivityLineID = 1, lastPreview = "hi" },
    }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local preview = conversations.new.lastPreview
    assert(preview == "recorded", "activity newer than the thread keeps its preview, got " .. tostring(preview))
  end

  -- test_merged_preview_is_a_status_line_in_the_same_second_as_the_activity
  do
    local conversations = {
      old = { messages = { line("s1", "system", "Jaina is offline.", 300) }, lastActivityAt = 300, lastPreview = "Jaina is offline." },
      new = { messages = { line("m1", "user", "hi", 300, 5) }, lastActivityAt = 300, lastActivityLineID = 5, lastPreview = "hi" },
    }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local merged = conversations.new
    local lastText = merged.messages[#merged.messages].text
    assert(lastText == "Jaina is offline.", "setup: the status line sorts last, got " .. tostring(lastText))
    assert(merged.lastPreview == "Jaina is offline.", "a same-second status line is the preview, got " .. tostring(merged.lastPreview))
  end

  -- test_merged_preview_keeps_a_same_second_line_kept_outside_the_thread_with_a_later_id
  do
    local conversations = {
      old = { messages = { line("m3", "user", "in thread", 300, 3) }, lastActivityAt = 300, lastActivityLineID = 5, lastPreview = "outside" },
      new = { messages = { line("m1", "user", "hi", 100, 1) }, lastActivityAt = 100, lastActivityLineID = 1, lastPreview = "hi" },
    }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local preview = conversations.new.lastPreview
    assert(preview == "outside", "a later line ID at the same second keeps its preview, got " .. tostring(preview))
  end
end
