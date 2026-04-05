local Store = require("WhisperMessenger.Model.ConversationStore")
local Queue = require("WhisperMessenger.Model.LockdownQueue")
local Router = require("WhisperMessenger.Core.EventRouter")

return function()
  -- test_incoming_whisper_marked_censored_when_api_reports_censored
  do
    _G.C_ChatInfo = {
      IsChatLineCensored = function(lineID)
        return lineID == 201
      end,
    }

    local state = {
      localProfileId = "me",
      store = Store.New({ maxMessagesPerConversation = 10 }),
      queue = Queue.New(),
      activeConversationKey = nil,
      availabilityByGUID = {},
      pendingOutgoing = {},
      now = function()
        return 1000
      end,
      isChatMessagingLocked = function()
        return false
      end,
    }

    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "this is #### censored",
      playerName = "Arthas-Area52",
      lineID = 201,
      guid = "Player-3676-0ABCDEF0",
    })

    local key = "wow::WOW::arthas-area52"
    local conversation = state.store.conversations[key]
    assert(conversation ~= nil, "test_censored: expected conversation to exist")
    assert(#conversation.messages == 1, "test_censored: expected 1 message")
    assert(
      conversation.messages[1].isCensored == true,
      "test_censored: expected isCensored=true on message with censored lineID"
    )
  end

  -- test_incoming_whisper_not_marked_censored_when_api_reports_uncensored
  do
    _G.C_ChatInfo = {
      IsChatLineCensored = function(_lineID)
        return false
      end,
    }

    local state = {
      localProfileId = "me",
      store = Store.New({ maxMessagesPerConversation = 10 }),
      queue = Queue.New(),
      activeConversationKey = nil,
      availabilityByGUID = {},
      pendingOutgoing = {},
      now = function()
        return 1001
      end,
      isChatMessagingLocked = function()
        return false
      end,
    }

    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "hello friend",
      playerName = "Jaina-Proudmoore",
      lineID = 202,
      guid = "Player-3676-0ABCDEF1",
    })

    local key = "wow::WOW::jaina-proudmoore"
    local conversation = state.store.conversations[key]
    assert(conversation ~= nil, "test_not_censored: expected conversation to exist")
    assert(
      conversation.messages[1].isCensored ~= true,
      "test_not_censored: isCensored should not be true for uncensored message"
    )
  end

  -- test_censored_without_api_available_does_not_error
  do
    _G.C_ChatInfo = nil

    local state = {
      localProfileId = "me",
      store = Store.New({ maxMessagesPerConversation = 10 }),
      queue = Queue.New(),
      activeConversationKey = nil,
      availabilityByGUID = {},
      pendingOutgoing = {},
      now = function()
        return 1002
      end,
      isChatMessagingLocked = function()
        return false
      end,
    }

    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "no api available",
      playerName = "Thrall-Durotan",
      lineID = 203,
      guid = "Player-3676-0ABCDEF2",
    })

    local key = "wow::WOW::thrall-durotan"
    local conversation = state.store.conversations[key]
    assert(conversation ~= nil, "test_no_api: expected conversation to exist")
    assert(
      conversation.messages[1].isCensored ~= true,
      "test_no_api: isCensored should not be true when API unavailable"
    )
  end

  -- test_bnet_whisper_marked_censored
  do
    _G.C_ChatInfo = {
      IsChatLineCensored = function(lineID)
        return lineID == 301
      end,
    }

    local state = {
      localProfileId = "me",
      store = Store.New({ maxMessagesPerConversation = 10 }),
      queue = Queue.New(),
      activeConversationKey = nil,
      availabilityByGUID = {},
      pendingOutgoing = {},
      now = function()
        return 1003
      end,
      isChatMessagingLocked = function()
        return false
      end,
    }

    Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", {
      text = "bn #### censored",
      playerName = "Jaina",
      lineID = 301,
      guid = nil,
      channel = "BN",
      bnetAccountID = 42,
      accountInfo = {
        battleTag = "Jaina#1234",
        gameAccountInfo = {
          characterName = "Jaina",
          realmName = "Proudmoore",
          playerGuid = "Player-60-0ABCDE123",
        },
      },
    })

    local key = "bnet::BN::jaina#1234"
    local conversation = state.store.conversations[key]
    assert(conversation ~= nil, "test_bnet_censored: expected conversation to exist")
    assert(
      conversation.messages[1].isCensored == true,
      "test_bnet_censored: expected isCensored=true on BNet censored message"
    )
  end

  _G.C_ChatInfo = nil
end
