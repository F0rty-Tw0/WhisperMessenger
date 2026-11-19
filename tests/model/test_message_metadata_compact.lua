local Store = require("WhisperMessenger.Model.ConversationStore")

-- A stored whisper line keeps only the fields something still reads, so a
-- character whisper fits in eight fields. Older versions read the same
-- fields, so a downgrade shows these lines unchanged.

local function countFields(message)
  local count = 0
  for _ in pairs(message) do
    count = count + 1
  end
  return count
end

local function characterWhisper(direction, overrides)
  local message = {
    id = "1001",
    direction = direction,
    kind = "user",
    text = "hello there",
    sentAt = 100,
    lineID = 1001,
    guid = "Player-1305-0A1B2C3D",
    playerName = "Somebody-Kazzak",
    channel = "WOW",
    className = "Paladin",
    classTag = "PALADIN",
    isCensored = false,
  }
  if direction == "out" then
    message.senderClassTag = "MAGE"
    message.senderName = "Myself"
  end
  for field, value in pairs(overrides or {}) do
    message[field] = value
  end
  return message
end

local function battleNetWhisper(direction)
  local message = characterWhisper(direction, {
    playerName = "Friend#1234",
    channel = "BN",
    bnetAccountID = 42,
    battleTag = "Friend#1234",
    gameAccountName = "Friendchar-Kazzak",
    classTag = "PRIEST",
  })
  return message
end

local KEY = "me::WOW::somebody-kazzak"
local BN_KEY = "me::BN::friend#1234"

return function()
  -- test_incoming_character_whisper_keeps_only_read_fields
  do
    local store = Store.New({})
    local message = characterWhisper("in")
    Store.AppendIncoming(store, KEY, message, false)
    local conversation = store.conversations[KEY]
    assert(conversation.guid == "Player-1305-0A1B2C3D" and conversation.classTag == "PALADIN", "the conversation takes the contact first")
    assert(message.guid == nil, "a whisper line drops the guid the conversation holds")
    assert(message.isCensored == nil, "a line that is not censored drops the flag")
    assert(message.classTag == nil, "a character whisper drops the class its conversation holds")
    assert(message.playerName == "Somebody-Kazzak" and message.channel == "WOW", "the sender name and channel stay for older versions")
    assert(message.id == "1001" and message.lineID == 1001 and message.kind == "user", "id, line and kind stay")
  end

  -- test_compacted_character_whisper_has_at_most_eight_fields
  do
    local store = Store.New({})
    local incoming = characterWhisper("in")
    local outgoing = characterWhisper("out", { id = "1002", lineID = 1002, sentAt = 101 })
    Store.AppendIncoming(store, KEY, incoming, true)
    Store.AppendOutgoing(store, KEY, outgoing)
    assert(countFields(incoming) <= 8, "incoming whisper keeps " .. countFields(incoming) .. " fields")
    assert(countFields(outgoing) <= 8, "outgoing whisper keeps " .. countFields(outgoing) .. " fields")
  end

  -- test_outgoing_whisper_drops_recipient_fields
  do
    local store = Store.New({})
    local message = characterWhisper("out")
    Store.AppendOutgoing(store, KEY, message)
    assert(store.conversations[KEY].displayName == "Somebody-Kazzak", "the conversation takes the recipient first")
    assert(message.playerName == nil and message.classTag == nil and message.guid == nil, "a sent line drops the recipient")
    assert(message.channel == nil, "a sent line drops its channel")
    assert(message.senderName == "Myself" and message.senderClassTag == "MAGE", "a sent line keeps the character that sent it")
  end

  -- test_battle_net_whisper_drops_account_fields_and_keeps_class
  do
    local store = Store.New({})
    local message = battleNetWhisper("in")
    Store.AppendIncoming(store, BN_KEY, message, false)
    local conversation = store.conversations[BN_KEY]
    assert(conversation.bnetAccountID == 42 and conversation.battleTag == "Friend#1234", "the conversation takes the account first")
    assert(message.bnetAccountID == nil and message.battleTag == nil and message.gameAccountName == nil, "a whisper line drops the account")
    assert(message.classTag == "PRIEST", "a Battle.net line keeps its character's class")
    assert(message.playerName == "Friend#1234" and message.channel == "BN", "a Battle.net line keeps sender and channel")
  end

  -- test_incoming_class_kept_when_it_differs_from_conversation
  do
    local store = Store.New({})
    Store.AppendIncoming(store, KEY, characterWhisper("in", { id = "2", lineID = 2, sentAt = 200 }), true)
    local older = characterWhisper("in", { id = "1", lineID = 1, sentAt = 50, classTag = "WARRIOR" })
    Store.InsertIncomingChronological(store, KEY, older, true)
    assert(older.classTag == "WARRIOR", "a class the conversation does not hold stays on the line")
  end

  -- test_class_change_stamps_old_class_on_lines_without_one
  do
    local store = Store.New({})
    local first = characterWhisper("in")
    Store.AppendIncoming(store, KEY, first, true)
    Store.AppendIncoming(store, KEY, characterWhisper("in", { id = "1002", lineID = 1002, sentAt = 101, classTag = "WARLOCK" }), true)
    assert(store.conversations[KEY].classTag == "WARLOCK", "the conversation follows the new class")
    assert(first.classTag == "PALADIN", "an earlier line keeps the class it arrived with")
  end

  -- test_group_lines_keep_sender_identity
  do
    local store = Store.New({})
    local message = characterWhisper("in", { channel = "PARTY" })
    Store.AppendIncoming(store, "me::PARTY::party", message, true)
    assert(message.guid == "Player-1305-0A1B2C3D" and message.classTag == "PALADIN", "a group line keeps its sender's guid and class")
    assert(message.playerName == "Somebody-Kazzak", "a group line keeps its sender's name")
  end

  -- test_unsent_record_keeps_resend_fields
  do
    local store = Store.New({})
    local record = characterWhisper("out", { delivery = "failed", bnetAccountID = 7, gameAccountName = "Alt-Kazzak" })
    Store.AppendOutgoing(store, KEY, record)
    assert(record.playerName == "Somebody-Kazzak" and record.guid == "Player-1305-0A1B2C3D", "a failed send keeps its target")
    assert(record.channel == "WOW" and record.bnetAccountID == 7 and record.gameAccountName == "Alt-Kazzak", "a failed send keeps how to resend")
  end

  -- test_censored_line_keeps_flag
  do
    local store = Store.New({})
    local message = characterWhisper("in", { isCensored = true })
    Store.AppendIncoming(store, KEY, message, true)
    assert(message.isCensored == true, "a censored line keeps the flag")
  end

  -- test_saved_full_shape_lines_stay_unchanged
  do
    local store = Store.New({})
    local saved = characterWhisper("in", { className = nil })
    store.conversations[KEY] = {
      messages = { saved },
      unreadCount = 0,
      channel = "WOW",
      displayName = "Somebody-Kazzak",
      guid = "Player-1305-0A1B2C3D",
      classTag = "PALADIN",
      lastActivityAt = 100,
    }
    local before = countFields(saved)
    Store.AppendIncoming(store, KEY, characterWhisper("in", { id = "1002", lineID = 1002, sentAt = 101 }), true)
    assert(countFields(saved) == before and saved.guid == "Player-1305-0A1B2C3D" and saved.classTag == "PALADIN", "a saved line is not rewritten")
  end
end
