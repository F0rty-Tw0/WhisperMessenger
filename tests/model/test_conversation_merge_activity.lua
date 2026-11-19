local ConversationMerge = require("WhisperMessenger.Model.ConversationMerge")

-- Merging two records of one chat: a record whose activity came only from the
-- status line that opened it gives way to the other record's real activity,
-- even when that real line is older.
return function()
  local function line(id, kind, text, sentAt, lineID)
    return { id = id, kind = kind, direction = "in", text = text, sentAt = sentAt, lineID = lineID }
  end

  local function statusOpened()
    return { messages = { line("s1", "system", "Jaina is offline.", 300) }, lastActivityAt = 300, lastPreview = "Jaina is offline." }
  end

  local function realChat()
    return { messages = { line("m1", "user", "hi", 100, 1) }, lastActivityAt = 100, lastActivityLineID = 1, lastPreview = "hi" }
  end

  -- test_merge_takes_real_activity_over_a_newer_status_opened_legacy_record
  do
    local conversations = { old = statusOpened(), new = realChat() }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local merged = conversations.new
    assert(merged.lastActivityAt == 100, "activity is the real line, got " .. tostring(merged.lastActivityAt))
    assert(merged.lastActivityLineID == 1, "activity line ID is the real line's, got " .. tostring(merged.lastActivityLineID))
  end

  -- test_merge_takes_real_activity_over_a_newer_status_opened_canonical_record
  do
    local conversations = { old = realChat(), new = statusOpened() }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local merged = conversations.new
    assert(merged.lastActivityAt == 100, "activity is the real line, got " .. tostring(merged.lastActivityAt))
    assert(merged.lastActivityLineID == 1, "activity line ID is the real line's, got " .. tostring(merged.lastActivityLineID))
  end

  -- test_merge_keeps_status_activity_when_the_other_record_has_none
  do
    local conversations = { old = statusOpened(), new = { messages = {} } }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local merged = conversations.new
    assert(merged.lastActivityAt == 300, "no activity elsewhere: the status line's, got " .. tostring(merged.lastActivityAt))
  end

  -- test_merge_keeps_the_newer_away_status_from_a_status_opened_record
  do
    local opened = statusOpened()
    opened.activeStatus = { text = "Busy", sentAt = 300 }
    local conversations = { old = opened, new = realChat() }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local status = conversations.new.activeStatus
    assert(type(status) == "table" and status.text == "Busy", "the newer away status survives, got " .. tostring(status))
  end

  -- test_merge_skips_transcript_entries_that_are_not_lines
  do
    local opened = statusOpened()
    table.insert(opened.messages, 1, 42)
    local conversations = { old = opened, new = realChat() }
    local ok, err = pcall(ConversationMerge.Rekey, conversations, "old", "new", 50)
    assert(ok, "a non-line entry does not break the merge: " .. tostring(err))
  end

  local function olderStatusOpened()
    local older = statusOpened()
    older.messages[1].sentAt = 200
    older.lastActivityAt = 200
    return older
  end

  -- test_merge_of_two_status_opened_records_keeps_the_newer_legacy_activity
  do
    local conversations = { old = statusOpened(), new = olderStatusOpened() }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local merged = conversations.new
    assert(merged.lastActivityAt == 300, "both status-opened: the newer one, got " .. tostring(merged.lastActivityAt))
  end

  -- test_merge_of_two_status_opened_records_keeps_the_newer_canonical_activity
  do
    local conversations = { old = olderStatusOpened(), new = statusOpened() }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local merged = conversations.new
    assert(merged.lastActivityAt == 300, "both status-opened: the newer one, got " .. tostring(merged.lastActivityAt))
  end
end
