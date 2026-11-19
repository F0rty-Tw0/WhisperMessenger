local Store = require("WhisperMessenger.Model.ConversationStore")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")

-- One friend, Jaina#1234 (World.B), who owns the character Arthas-Area52
-- (World.K, World.NAME). World.FRIEND is what GetAccountInfoByGUID answers
-- for her character.
--   World.NewState(accountInfo) -> state, lookups
--       router-ready state: store, merge map, pending queue, clock at 1000;
--       GetAccountInfoByGUID answers accountInfo and counts calls in lookups.n
--   World.SeedB(state) -> B's record      store B as a Battle.net chat
--   World.SeedK(state, line)               store K as a character chat with one
--                                          line (default: an unread incoming line)
--   World.MergedState() -> state, lookups  B stored and K already merged into it
--   World.Last(conversation) -> its newest line
local World = {}

World.K = "wow::WOW::arthas-area52"
World.B = "bnet::BN::jaina#1234"
World.NAME = "Arthas-Area52"
World.FRIEND = { bnetAccountID = 77, battleTag = "Jaina#1234" }

function World.NewState(accountInfo)
  local lookups = { n = 0 }
  local state = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 50, maxConversations = 10 }),
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 1000
    end,
    accountState = { settings = {} },
    characterMerges = CharacterMergeMap.Ensure({}),
    bnetApi = {
      GetAccountInfoByGUID = function()
        lookups.n = lookups.n + 1
        return accountInfo
      end,
    },
  }

  return state, lookups
end

function World.SeedB(state)
  local metadata = { channel = "BN", displayName = "Jaina#1234", battleTag = "Jaina#1234", bnetAccountID = 77 }

  return Store.EnsureConversation(state.store, World.B, metadata)
end

function World.SeedK(state, line)
  local defaultLine =
    { id = "50", lineID = 50, kind = "user", direction = "in", text = "earlier", sentAt = 500, channel = "WOW", playerName = World.NAME }
  state.store.conversations[World.K] = {
    conversationKey = World.K,
    channel = "WOW",
    displayName = World.NAME,
    unreadCount = 1,
    unreadActivityCount = 0,
    lastActivityAt = 500,
    messages = { line or defaultLine },
  }
end

function World.MergedState()
  local state, lookups = World.NewState(nil)
  World.SeedB(state)
  CharacterMergeMap.Record(state.characterMerges, World.K, World.B, World.NAME)

  return state, lookups
end

function World.Last(conversation)
  return conversation.messages[#conversation.messages]
end

return World
