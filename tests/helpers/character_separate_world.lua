local Store = require("WhisperMessenger.Model.ConversationStore")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")

-- One Battle.net chat (World.B, Jaina#1234) with two characters folded in:
-- World.K (Arthas, same realm) and World.K_OTHER_REALM (Arthas-Area52).
--   World.Fresh(config) -> store, merges   B stored, both characters merged
--   World.CharacterLine(id, sentAt, text, name, direction, classTag)
--   World.BnLine(id, sentAt, text)
--   World.Texts(conversation) -> "a,b,c"   the chat's line texts in order
local World = {}

local K = "wow::WOW::arthas"
local NAME = "Arthas"
-- The same character name from another realm: another key, merged on its own.
local K_OTHER_REALM = "wow::WOW::arthas-area52"
local NAME_OTHER_REALM = "Arthas-Area52"
local B = "bnet::BN::jaina#1234"

function World.BnLine(id, sentAt, text)
  return { id = id, lineID = tonumber(id), kind = "user", direction = "in", text = text, sentAt = sentAt, channel = "BN", playerName = "Jaina#1234" }
end

function World.CharacterLine(id, sentAt, text, name, direction, classTag)
  return {
    id = id,
    lineID = tonumber(id),
    kind = "user",
    direction = direction,
    text = text,
    sentAt = sentAt,
    channel = "WOW",
    playerName = name,
    classTag = classTag,
  }
end

-- B after two characters folded in. Unread 2 = the two newest incoming
-- lines ("k newest" from K, "b newest" from the app).
local function mergedChat()
  return {
    conversationKey = B,
    channel = "BN",
    displayName = "Jaina#1234",
    battleTag = "Jaina#1234",
    bnetAccountID = 77,
    nickname = "Jay",
    note = "raid lead",
    draft = "unsent",
    unreadCount = 2,
    unreadActivityCount = 0,
    lastActivityAt = 600,
    lastActivityLineID = 60,
    lastPreview = "k newest",
    lastIncomingAt = 600,
    lastIncomingLineID = 60,
    lastIncomingSender = NAME,
    lastIncomingPreview = "k newest",
    messages = {
      World.BnLine("10", 100, "b in"),
      World.CharacterLine("20", 200, "k old", NAME, "in", "PALADIN"),
      World.CharacterLine("30", 300, "to k", NAME, "out"),
      World.CharacterLine("40", 400, "other realm", NAME_OTHER_REALM, "in", "MAGE"),
      World.BnLine("50", 500, "b newest"),
      { id = "550", kind = "system", text = "Arthas is offline", sentAt = 550, channel = "WOW", playerName = NAME },
      World.CharacterLine("60", 600, "k newest", NAME, "in", "DEATHKNIGHT"),
    },
  }
end

function World.Fresh(config)
  local store = Store.New(config or { maxMessagesPerConversation = 50, maxConversations = 10 })
  store.conversations[B] = mergedChat()
  local merges = CharacterMergeMap.Ensure({})
  CharacterMergeMap.Record(merges, K, B, NAME)
  CharacterMergeMap.Record(merges, K_OTHER_REALM, B, NAME_OTHER_REALM)
  return store, merges
end

function World.Texts(conversation)
  local list = {}
  for index, message in ipairs(conversation.messages) do
    list[index] = message.text
  end
  return table.concat(list, ",")
end

World.K = K
World.NAME = NAME
World.K_OTHER_REALM = K_OTHER_REALM
World.NAME_OTHER_REALM = NAME_OTHER_REALM
World.B = B

return World
