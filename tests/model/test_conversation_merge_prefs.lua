local ConversationMerge = require("WhisperMessenger.Model.ConversationMerge")

-- When a Battle.net friend's conversation is re-keyed onto an existing
-- record, the player's mute, nickname, note and draft must survive.
return function()
  -- test_legacy_prefs_carry_into_canonical_record
  do
    local conversations = {
      old = { messages = {}, muted = true, nickname = "Boss", note = "raid lead", draft = "brb" },
      new = { messages = {} },
    }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local merged = conversations.new
    assert(conversations.old == nil, "old key removed")
    assert(merged.muted == true, "mute carried over")
    assert(merged.nickname == "Boss" and merged.note == "raid lead", "nickname and note carried over")
    assert(merged.draft == "brb", "draft carried over")
  end

  -- test_canonical_prefs_win_over_legacy
  do
    local conversations = {
      old = { messages = {}, nickname = "Old", note = "old note", draft = "old draft" },
      new = { messages = {}, nickname = "New", note = "new note", draft = "new draft" },
    }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    local merged = conversations.new
    assert(merged.nickname == "New" and merged.note == "new note" and merged.draft == "new draft", "canonical values kept")
  end

  -- test_either_side_muted_stays_muted
  do
    local conversations = { old = { messages = {} }, new = { messages = {}, muted = true } }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    assert(conversations.new.muted == true, "canonical mute kept")
  end

  -- test_unmuted_merge_leaves_no_flag
  do
    local conversations = { old = { messages = {} }, new = { messages = {} } }
    ConversationMerge.Rekey(conversations, "old", "new", 50)
    assert(conversations.new.muted == nil, "no mute flag invented")
  end
end
