local CharacterSeparate = require("WhisperMessenger.Model.CharacterSeparate")
local World = require("tests.helpers.character_separate_world")

-- "Separate <Character>" when the character's own chat still exists (a chat
-- written after a downgrade): the moved lines join it by time.
local K, NAME, B = World.K, World.NAME, World.B
local characterLine, fresh, texts = World.CharacterLine, World.Fresh, World.Texts

return function()
  -- test_existing_character_chat_takes_the_lines_by_time
  do
    local store, merges = fresh()
    store.conversations[K] = {
      conversationKey = K,
      channel = "WOW",
      displayName = NAME,
      guid = "Player-1",
      classTag = "PRIEST",
      unreadCount = 1,
      unreadActivityCount = 0,
      lastActivityAt = 250,
      lastActivityLineID = 25,
      lastPreview = "after downgrade",
      messages = { characterLine("25", 250, "after downgrade", NAME, "in") },
    }
    local character = CharacterSeparate.Separate(store, merges, B, K)
    assert(texts(character) == "k old,after downgrade,to k,Arthas is offline,k newest", "lines merged by time, got " .. texts(character))
    assert(character.unreadCount == 2, "its own unread plus the moved one, got " .. tostring(character.unreadCount))
    assert(character.guid == "Player-1" and character.classTag == "PRIEST", "the existing chat keeps its identity")
    assert(character.lastPreview == "k newest" and character.lastActivityAt == 600, "recomputed over the merged lines")
  end

  -- test_existing_character_chat_is_trimmed_to_the_cap
  do
    local store, merges = fresh({ maxMessagesPerConversation = 3, maxConversations = 10 })
    store.conversations[K] = {
      conversationKey = K,
      channel = "WOW",
      displayName = NAME,
      unreadCount = 0,
      unreadActivityCount = 0,
      lastActivityAt = 250,
      messages = { characterLine("25", 250, "after downgrade", NAME, "in") },
    }
    local character = CharacterSeparate.Separate(store, merges, B, K)
    assert(texts(character) == "to k,Arthas is offline,k newest", "the oldest lines go past the cap, got " .. texts(character))
    assert(character.classTag == "DEATHKNIGHT", "a chat without a class takes the newest one, got " .. tostring(character.classTag))
  end

  -- test_existing_line_comes_first_on_a_tie
  do
    local store, merges = fresh()
    store.conversations[K] = {
      conversationKey = K,
      channel = "WOW",
      displayName = NAME,
      unreadCount = 0,
      unreadActivityCount = 0,
      lastActivityAt = 200,
      messages = { characterLine("21", 200, "same time", NAME, "in") },
    }
    local character = CharacterSeparate.Separate(store, merges, B, K)
    assert(texts(character) == "same time,k old,to k,Arthas is offline,k newest", "the chat's own line wins the tie, got " .. texts(character))
  end
end
