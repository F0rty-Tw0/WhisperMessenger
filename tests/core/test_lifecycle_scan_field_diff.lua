local ScanFieldDiff = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.ScanFieldDiff")

-- A BN scan marks a conversation changed only when a plain field the cards
-- show was added, removed or rewritten.
return function()
  -- test_untouched_conversation_is_unchanged
  do
    local conversation = { battleTag = "Thrall#1", bnetAccountID = 7, meta = {} }
    ScanFieldDiff.Capture(conversation)
    assert(ScanFieldDiff.Changed(conversation) == false, "no writes: unchanged")
  end

  -- test_rewritten_field_is_changed
  do
    local conversation = { battleTag = "Thrall#1", bnetAccountID = 7 }
    ScanFieldDiff.Capture(conversation)
    conversation.bnetAccountID = 8
    assert(ScanFieldDiff.Changed(conversation) == true, "rewritten field: changed")
  end

  -- test_added_and_removed_fields_are_changed
  do
    local conversation = { battleTag = "Thrall#1" }
    ScanFieldDiff.Capture(conversation)
    conversation.gameAccountName = "Thrall-Area52"
    assert(ScanFieldDiff.Changed(conversation) == true, "added field: changed")

    conversation = { battleTag = "Thrall#1", className = "SHAMAN" }
    ScanFieldDiff.Capture(conversation)
    conversation.className = nil
    assert(ScanFieldDiff.Changed(conversation) == true, "removed field: changed")
  end

  -- test_table_fields_and_last_seen_are_ignored
  do
    local conversation = { battleTag = "Thrall#1", lastSeenAt = 1, messages = {} }
    ScanFieldDiff.Capture(conversation)
    conversation.lastSeenAt = 2
    conversation.messages = {}
    assert(ScanFieldDiff.Changed(conversation) == false, "last seen and tables: unchanged")
  end

  -- test_capture_forgets_the_previous_conversation
  do
    ScanFieldDiff.Capture({ battleTag = "A#1", className = "MAGE" })
    local conversation = { battleTag = "B#2" }
    ScanFieldDiff.Capture(conversation)
    assert(ScanFieldDiff.Changed(conversation) == false, "fields of the previous capture are gone")
  end
end
