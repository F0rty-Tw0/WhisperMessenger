local ContactPrefs = require("WhisperMessenger.Model.ContactPrefs")
local Store = require("WhisperMessenger.Model.ConversationStore")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")

local KEY = "me::WOW::arthas"

local function newStore()
  local store = Store.New({ maxMessagesPerConversation = 50, maxConversations = 10, messageMaxAge = 86400, conversationMaxAge = 86400 })
  Store.EnsureConversation(store, KEY)
  return store
end

return function()
  -- test_mute_is_stored_on_the_conversation_record
  local store = newStore()
  ContactPrefs.Apply(store, KEY, { muted = true })
  assert(store.conversations[KEY].muted == true, "mute persists on the saved record")

  -- test_unmute_removes_the_flag
  ContactPrefs.Apply(store, KEY, { muted = false })
  assert(store.conversations[KEY].muted == nil, "unmute leaves no flag behind")

  -- test_nickname_is_trimmed
  ContactPrefs.Apply(store, KEY, { nickname = "  Big Boss  " })
  assert(store.conversations[KEY].nickname == "Big Boss", "nickname trimmed")

  -- test_nickname_capped_at_32_characters
  ContactPrefs.Apply(store, KEY, { nickname = string.rep("n", 40) })
  assert(store.conversations[KEY].nickname == string.rep("n", 32), "nickname capped at 32 characters")

  -- test_empty_nickname_clears
  ContactPrefs.Apply(store, KEY, { nickname = "   " })
  assert(store.conversations[KEY].nickname == nil, "blank nickname clears it")

  -- test_note_is_trimmed_and_capped_at_255_bytes
  ContactPrefs.Apply(store, KEY, { note = "  met in Valdrakken  " })
  assert(store.conversations[KEY].note == "met in Valdrakken", "note trimmed")
  ContactPrefs.Apply(store, KEY, { note = string.rep("x", 300) })
  assert(#store.conversations[KEY].note == 255, "note capped at 255 bytes")

  -- test_empty_note_clears
  ContactPrefs.Apply(store, KEY, { note = "" })
  assert(store.conversations[KEY].note == nil, "empty note clears it")

  -- test_notify_online_saved_and_cleared
  ContactPrefs.Apply(store, KEY, { notifyOnline = true })
  assert(store.conversations[KEY].notifyOnline == true, "flag saved")
  assert(ConversationSnapshot.Build(KEY, store.conversations[KEY]).notifyOnline == true, "row item carries the flag")
  ContactPrefs.Apply(store, KEY, { notifyOnline = false })
  assert(store.conversations[KEY].notifyOnline == nil, "flag cleared, nothing saved")

  -- test_missing_conversation_is_ignored
  ContactPrefs.Apply(store, "nope", { muted = true, nickname = "x" })
  assert(store.conversations["nope"] == nil, "prefs never create a conversation")

  -- test_apply_routes_each_change
  ContactPrefs.Apply(store, KEY, { muted = true, nickname = "Boss", note = "tank" })
  local record = store.conversations[KEY]
  assert(record.muted == true and record.nickname == "Boss" and record.note == "tank", "Apply sets every given field")
  ContactPrefs.Apply(store, KEY, { muted = false })
  assert(record.muted == nil and record.nickname == "Boss", "Apply leaves fields it was not given")

  -- test_snapshot_exposes_prefs_to_the_ui
  record.muted = true
  record.hasUnreadMention = true
  local snapshot = ConversationSnapshot.Build(KEY, record)
  assert(snapshot.muted == true, "snapshot carries muted")
  assert(snapshot.nickname == "Boss" and snapshot.note == "tank", "snapshot carries nickname and note")
  assert(snapshot.hasUnreadMention == true, "snapshot carries the unread mention flag")
end
