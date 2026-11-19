local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local CharacterSeparate = require("WhisperMessenger.Model.CharacterSeparate")
local World = require("tests.helpers.character_separate_world")

-- "Separate <Character>" moves one character's lines out of their Battle.net
-- friend's chat into the character's own chat, and remembers the character
-- so it never folds in again.
local K, NAME, K_OTHER_REALM, B = World.K, World.NAME, World.K_OTHER_REALM, World.B
local bnLine, characterLine, fresh, texts = World.BnLine, World.CharacterLine, World.Fresh, World.Texts

return function()
  -- test_separate_moves_only_that_characters_lines_in_order
  do
    local store, merges = fresh()
    local character = CharacterSeparate.Separate(store, merges, B, K)
    assert(character ~= nil and store.conversations[K] == character, "the character's chat comes back")
    assert(texts(character) == "k old,to k,Arthas is offline,k newest", "only that character's lines, in order, got " .. texts(character))
    assert(texts(store.conversations[B]) == "b in,other realm,b newest", "the friend's chat keeps the rest, got " .. texts(store.conversations[B]))
  end

  -- test_other_realm_character_stays_merged
  do
    local store, merges = fresh()
    CharacterSeparate.Separate(store, merges, B, K)
    assert(CharacterMergeMap.Get(merges, K_OTHER_REALM).bnetKey == B, "the same name from another realm stays merged")
    assert(CharacterMergeMap.IsSeparated(merges, K_OTHER_REALM) == false, "and is not separated")
    assert(store.conversations[K_OTHER_REALM] == nil, "its lines stay in the friend's chat")
  end

  -- test_separate_remembers_the_character
  do
    local store, merges = fresh()
    CharacterSeparate.Separate(store, merges, B, K)
    assert(CharacterMergeMap.Get(merges, K) == nil, "the character is no longer merged")
    assert(CharacterMergeMap.IsSeparated(merges, K) == true, "the character is separated for good")
  end

  -- test_character_chat_gets_whisper_identity_and_newest_class
  do
    local store, merges = fresh()
    local character = CharacterSeparate.Separate(store, merges, B, K)
    assert(character.conversationKey == K and character.channel == "WOW", "a character whisper chat")
    assert(character.displayName == NAME and character.guid == nil, "named from the map, no guid")
    assert(character.classTag == "DEATHKNIGHT", "class from the newest line that has one, got " .. tostring(character.classTag))
  end

  -- test_preview_activity_and_last_incoming_recomputed_on_both
  do
    local store, merges = fresh()
    local character = CharacterSeparate.Separate(store, merges, B, K)
    local friend = store.conversations[B]
    assert(
      character.lastPreview == "k newest" and character.lastActivityAt == 600 and character.lastActivityLineID == 60,
      "the character's newest line"
    )
    assert(
      character.lastIncomingPreview == "k newest" and character.lastIncomingAt == 600 and character.lastIncomingSender == NAME,
      "the character's newest incoming line"
    )
    assert(
      friend.lastPreview == "b newest" and friend.lastActivityAt == 500 and friend.lastActivityLineID == 50,
      "the friend's chat drops to its own newest line"
    )
    assert(
      friend.lastIncomingPreview == "b newest" and friend.lastIncomingAt == 500 and friend.lastIncomingSender == "Jaina#1234",
      "the friend's newest incoming line"
    )
  end

  -- test_status_line_shows_in_preview_but_does_not_move_activity
  do
    local store, merges = fresh()
    table.remove(store.conversations[B].messages) -- drop "k newest": the status line is now K's newest
    local character = CharacterSeparate.Separate(store, merges, B, K)
    assert(character.lastPreview == "Arthas is offline", "the preview shows the newest line of any kind")
    assert(character.lastActivityAt == 300, "activity stays on the last real line, got " .. tostring(character.lastActivityAt))
  end

  -- test_only_status_lines_still_set_activity
  do
    local store, merges = fresh()
    local friend = store.conversations[B]
    friend.messages = { bnLine("10", 100, "b in"), friend.messages[6] }
    local character = CharacterSeparate.Separate(store, merges, B, K)
    assert(character.lastActivityAt == 550, "a chat of status lines only takes its newest, got " .. tostring(character.lastActivityAt))
  end

  -- test_unread_split_between_the_two_chats
  do
    local store, merges = fresh()
    local character = CharacterSeparate.Separate(store, merges, B, K)
    assert(character.unreadCount == 1, "the unread line from the character moves with it, got " .. tostring(character.unreadCount))
    assert(store.conversations[B].unreadCount == 1, "the unread line from the app stays, got " .. tostring(store.conversations[B].unreadCount))
  end

  -- test_activity_unread_is_not_counted_as_a_message
  do
    local store, merges = fresh()
    local friend = store.conversations[B]
    friend.unreadCount = 4
    friend.unreadActivityCount = 1
    local character = CharacterSeparate.Separate(store, merges, B, K)
    assert(character.unreadCount == 1, "three unread messages, one of them the character's, got " .. tostring(character.unreadCount))
    assert(friend.unreadCount == 3 and friend.unreadActivityCount == 1, "the activity unread stays on the friend's chat")
  end

  -- test_nickname_note_pin_draft_stay_on_the_battle_net_chat
  do
    local store, merges = fresh()
    store.conversations[B].pinned = true
    local character = CharacterSeparate.Separate(store, merges, B, K)
    local friend = store.conversations[B]
    assert(
      friend.nickname == "Jay" and friend.note == "raid lead" and friend.pinned == true and friend.draft == "unsent",
      "the friend's chat keeps its prefs"
    )
    assert(
      character.nickname == nil and character.note == nil and character.pinned == nil and character.draft == nil,
      "the character's chat starts without them"
    )
    assert(friend.channel == "BN" and friend.bnetAccountID == 77, "the friend's chat stays a Battle.net chat")
  end

  -- test_no_lines_left_creates_no_character_chat
  do
    local store, merges = fresh()
    store.conversations[B].messages = { bnLine("10", 100, "b in") }
    local character = CharacterSeparate.Separate(store, merges, B, K)
    assert(character == nil and store.conversations[K] == nil, "no lines for the character: no chat")
    assert(CharacterMergeMap.IsSeparated(merges, K) == true, "the character is still separated")
  end

  -- test_friend_chat_left_empty_keeps_its_activity
  do
    local store, merges = fresh()
    local friend = store.conversations[B]
    friend.messages = { characterLine("20", 200, "k old", NAME, "in") }
    CharacterSeparate.Separate(store, merges, B, K)
    assert(#friend.messages == 0 and friend.lastActivityAt == 600, "an emptied chat keeps its activity, got " .. tostring(friend.lastActivityAt))
    assert(friend.lastPreview == nil and friend.lastIncomingPreview == nil and friend.lastIncomingAt == nil, "and shows no stale preview")
  end

  -- test_separate_never_evicts_the_battle_net_chat
  do
    local store, merges = fresh({ maxMessagesPerConversation = 50, maxConversations = 1 })
    CharacterSeparate.Separate(store, merges, B, K)
    assert(
      store.conversations[B] ~= nil and store.conversations[K] ~= nil,
      "both chats exist; the character chat is not made through EnsureConversation"
    )
  end

  -- test_separate_clears_the_cached_retention_times
  do
    local store, merges = fresh()
    store.messageRetentionAt[B] = 1
    store.messageRetentionAt[K] = 1
    CharacterSeparate.Separate(store, merges, B, K)
    assert(store.messageRetentionAt[B] == nil and store.messageRetentionAt[K] == nil, "both chats' retention times are worked out again")
  end

  -- test_separate_of_an_unmerged_character_does_nothing
  do
    local store, merges = fresh()
    local before = texts(store.conversations[B])
    assert(CharacterSeparate.Separate(store, merges, B, "wow::WOW::thrall") == nil, "nothing to separate")
    assert(texts(store.conversations[B]) == before, "the friend's chat is untouched")
    assert(CharacterMergeMap.IsSeparated(merges, "wow::WOW::thrall") == false, "a character never merged is not marked")
  end

  -- test_separate_from_another_chat_does_nothing
  do
    local store, merges = fresh()
    assert(CharacterSeparate.Separate(store, merges, "bnet::BN::thrall#1", K) == nil, "the character is merged elsewhere")
    assert(CharacterMergeMap.Get(merges, K) ~= nil, "and stays merged")
  end

  -- test_missing_battle_net_chat_still_separates
  do
    local store, merges = fresh()
    store.conversations[B] = nil
    assert(CharacterSeparate.Separate(store, merges, B, K) == nil, "no chat to split")
    assert(CharacterMergeMap.IsSeparated(merges, K) == true, "the character is separated anyway")
  end
end
