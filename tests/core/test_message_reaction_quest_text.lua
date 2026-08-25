local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local Router = require("WhisperMessenger.Core.EventRouter")
local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local QuestLinkClassic = require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")

local function newStore()
  return Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 })
end

local function newReceiver(now)
  return {
    localProfileId = "me",
    store = newStore(),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return now
    end,
  }
end

return function()
  assert(type(QuestLinkClassic.CanonicalizeForTransport) == "function", "quest module should expose transport-stable reaction text")

  local rich = "check |cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r"
  local plain = "check [Apprentice's Duties (471)]"
  local stripped = "check [Apprentice's Duties]"
  assert(QuestLinkClassic.CanonicalizeForTransport(rich) == stripped, "rich quest link should canonicalize to transport-visible text")
  assert(QuestLinkClassic.CanonicalizeForTransport(plain) == stripped, "plain quest reference should canonicalize to transport-visible text")
  assert(QuestLinkClassic.CanonicalizeForTransport(stripped) == stripped, "already stripped event text should remain stable")

  local savedClassic = FlavorCompat.isClassic
  FlavorCompat.isClassic = true

  -- Classic character whisper: sender metadata pairs with stripped raw event text in both orders.
  do
    local addonPayload
    local sender = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 100
      end,
      chatApi = {
        SendChatMessage = function() end,
        RegisterAddonMessagePrefix = function() end,
        SendAddonMessage = function(prefix, payload)
          if prefix == "WMRX" then
            addonPayload = payload
          end
        end,
      },
      bnetApi = {},
    }
    assert(SendHandler.HandleSend(sender, {
      conversationKey = "wow::WOW::arthas-area52",
      target = "Arthas-Area52",
      displayName = "Arthas-Area52",
      guid = "Player-1",
      channel = "WOW",
      text = rich,
    }, function() end) == true, "Classic WOW quest whisper should send")
    local identity = assert(Protocol.Decode(addonPayload), "Classic WOW send should emit WMRX identity")

    local metadataFirst = newReceiver(200)
    Router.HandleEvent(metadataFirst, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = addonPayload,
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    local conversation = Router.HandleEvent(metadataFirst, "CHAT_MSG_WHISPER", {
      text = stripped,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 1,
    })
    assert(conversation.messages[1].wireId == identity.wireId, "Classic WOW metadata-first quest text should pair")

    local messageFirst = newReceiver(300)
    conversation = Router.HandleEvent(messageFirst, "CHAT_MSG_WHISPER", {
      text = stripped,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 2,
    })
    Router.HandleEvent(messageFirst, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = addonPayload,
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    assert(conversation.messages[1].wireId == identity.wireId, "Classic WOW message-first quest text should pair")
  end

  -- Classic Battle.net: rich sender text pairs with stripped raw BN event text in both orders.
  do
    local addonPayload
    local accountInfo = {
      bnetAccountID = 77,
      battleTag = "Jaina#1234",
      gameAccountInfo = { gameAccountID = 9001, characterName = "Jaina", realmName = "Proudmoore" },
    }
    local sender = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 400
      end,
      chatApi = { RegisterAddonMessagePrefix = function() end },
      bnetApi = {
        SendWhisper = function() end,
        SendGameData = function(_, prefix, payload)
          if prefix == "WMRX" then
            addonPayload = payload
          end
        end,
        GetAccountInfoByID = function()
          return accountInfo
        end,
        GetNumFriends = function()
          return 1
        end,
        GetFriendAccountInfo = function()
          return accountInfo
        end,
      },
    }
    sender.store.conversations["bnet::BN::jaina#1234"] = {
      conversationKey = "bnet::BN::jaina#1234",
      channel = "BN",
      battleTag = "Jaina#1234",
      bnetAccountID = 77,
      messages = {},
    }
    assert(SendHandler.HandleSend(sender, {
      conversationKey = "bnet::BN::jaina#1234",
      displayName = "Jaina#1234",
      battleTag = "Jaina#1234",
      channel = "BN",
      bnetAccountID = 77,
      text = rich,
    }, function() end) == true, "Classic BN quest whisper should send")
    local identity = assert(Protocol.Decode(addonPayload), "Classic BN send should emit WMRX identity")

    local metadataFirst = newReceiver(500)
    Router.HandleEvent(metadataFirst, "BN_CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = addonPayload,
      channel = "WHISPER",
      bnetAccountID = 77,
    })
    local conversation = Router.HandleEvent(metadataFirst, "CHAT_MSG_BN_WHISPER", {
      text = stripped,
      playerName = "Jaina",
      channel = "BN",
      bnetAccountID = 77,
      accountInfo = accountInfo,
      lineID = 3,
    })
    assert(conversation.messages[1].wireId == identity.wireId, "Classic BN metadata-first quest text should pair")

    local messageFirst = newReceiver(600)
    conversation = Router.HandleEvent(messageFirst, "CHAT_MSG_BN_WHISPER", {
      text = stripped,
      playerName = "Jaina",
      channel = "BN",
      bnetAccountID = 77,
      accountInfo = accountInfo,
      lineID = 4,
    })
    Router.HandleEvent(messageFirst, "BN_CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = addonPayload,
      channel = "WHISPER",
      bnetAccountID = 77,
    })
    assert(conversation.messages[1].wireId == identity.wireId, "Classic BN message-first quest text should pair")
  end

  -- Reaction fallback checksums also use canonical text for both delivery orders.
  do
    local normalFallback
    local operationPayload
    local sender = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 700
      end,
      chatApi = {
        SendChatMessage = function(text)
          normalFallback = text
        end,
        RegisterAddonMessagePrefix = function() end,
        SendAddonMessage = function(prefix, payload)
          if prefix == "WMRX" then
            operationPayload = payload
          end
        end,
      },
      bnetApi = {},
    }
    local initialFallback = Protocol.BuildFallback("heart", "set", rich)
    SendHandler.HandleSend(sender, {
      conversationKey = "wow::WOW::arthas-area52",
      target = "Arthas-Area52",
      displayName = "Arthas-Area52",
      guid = "Player-1",
      channel = "WOW",
      text = initialFallback,
      reactionControl = {
        actorName = "Artio",
        sourceText = rich,
        operation = {
          type = "reaction",
          operation = "set",
          key = "heart",
          wireId = "questtarget",
        },
      },
    }, function() end)
    local rawFallback = QuestLinkClassic.CanonicalizeForTransport(normalFallback)

    for _, metadataFirst in ipairs({ true, false }) do
      local receiver = newReceiver(metadataFirst and 800 or 900)
      local key = "wow::WOW::arthas-area52"
      local target = { kind = "user", direction = "out", text = rich, wireId = "questtarget", sentAt = 690 }
      receiver.store.conversations[key] = {
        conversationKey = key,
        messages = { target },
        unreadCount = 0,
        lastPreview = rich,
        lastActivityAt = 690,
      }
      local metadataEvent = {
        prefix = "WMRX",
        text = operationPayload,
        channel = "WHISPER",
        playerName = "Arthas-Area52",
      }
      local whisperEvent = {
        text = rawFallback,
        playerName = "Arthas-Area52",
        guid = "Player-1",
        lineID = metadataFirst and 5 or 6,
      }
      if metadataFirst then
        Router.HandleEvent(receiver, "CHAT_MSG_ADDON", metadataEvent)
        Router.HandleEvent(receiver, "CHAT_MSG_WHISPER", whisperEvent)
      else
        Router.HandleEvent(receiver, "CHAT_MSG_WHISPER", whisperEvent)
        Router.HandleEvent(receiver, "CHAT_MSG_ADDON", metadataEvent)
      end
      assert(target.reaction and target.reaction.key == "heart", "Classic WOW quest fallback should correlate in both delivery orders")
      assert(#receiver.store.conversations[key].messages == 1, "Classic WOW correlated quest fallback should stay hidden")
    end
  end

  do
    local normalFallback
    local operationPayload
    local accountInfo = {
      bnetAccountID = 77,
      battleTag = "Jaina#1234",
      gameAccountInfo = { gameAccountID = 9001, characterName = "Jaina", realmName = "Proudmoore" },
    }
    local sender = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 1000
      end,
      chatApi = { RegisterAddonMessagePrefix = function() end },
      bnetApi = {
        SendWhisper = function(_, text)
          normalFallback = text
        end,
        SendGameData = function(_, prefix, payload)
          if prefix == "WMRX" then
            operationPayload = payload
          end
        end,
        GetAccountInfoByID = function()
          return accountInfo
        end,
        GetNumFriends = function()
          return 1
        end,
        GetFriendAccountInfo = function()
          return accountInfo
        end,
      },
    }
    local key = "bnet::BN::jaina#1234"
    sender.store.conversations[key] = {
      conversationKey = key,
      channel = "BN",
      battleTag = "Jaina#1234",
      bnetAccountID = 77,
      messages = {},
    }
    local initialFallback = Protocol.BuildFallback("gg", "set", rich)
    SendHandler.HandleSend(sender, {
      conversationKey = key,
      displayName = "Jaina#1234",
      battleTag = "Jaina#1234",
      channel = "BN",
      bnetAccountID = 77,
      text = initialFallback,
      reactionControl = {
        actorName = "Artio",
        sourceText = rich,
        operation = {
          type = "reaction",
          operation = "set",
          key = "gg",
          wireId = "bnquesttarget",
        },
      },
    }, function() end)
    local rawFallback = QuestLinkClassic.CanonicalizeForTransport(normalFallback)

    for _, metadataFirst in ipairs({ true, false }) do
      local receiver = newReceiver(metadataFirst and 1100 or 1200)
      local target = { kind = "user", direction = "out", text = rich, wireId = "bnquesttarget", sentAt = 990, channel = "BN" }
      receiver.store.conversations[key] = {
        conversationKey = key,
        channel = "BN",
        battleTag = "Jaina#1234",
        bnetAccountID = 77,
        messages = { target },
        unreadCount = 0,
        lastPreview = rich,
        lastActivityAt = 990,
      }
      local metadataEvent = {
        prefix = "WMRX",
        text = operationPayload,
        channel = "WHISPER",
        bnetAccountID = 77,
      }
      local whisperEvent = {
        text = rawFallback,
        playerName = "Jaina",
        channel = "BN",
        bnetAccountID = 77,
        accountInfo = accountInfo,
        lineID = metadataFirst and 7 or 8,
      }
      if metadataFirst then
        Router.HandleEvent(receiver, "BN_CHAT_MSG_ADDON", metadataEvent)
        Router.HandleEvent(receiver, "CHAT_MSG_BN_WHISPER", whisperEvent)
      else
        Router.HandleEvent(receiver, "CHAT_MSG_BN_WHISPER", whisperEvent)
        Router.HandleEvent(receiver, "BN_CHAT_MSG_ADDON", metadataEvent)
      end
      assert(target.reaction and target.reaction.key == "gg", "Classic BN quest fallback should correlate in both delivery orders")
      assert(#receiver.store.conversations[key].messages == 1, "Classic BN correlated quest fallback should stay hidden")
    end
  end

  -- Legacy target fingerprint keeps quest IDs even though fallback correlation drops them.
  do
    local olderSource = "|cffffff00|Hquest:471:0|h[Shared Quest Name]|h|r"
    local newerSource = "|cffffff00|Hquest:999:0|h[Shared Quest Name]|h|r"
    local normalFallback
    local operationPayload
    local sender = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 1300
      end,
      chatApi = {
        SendChatMessage = function(text)
          normalFallback = text
        end,
        RegisterAddonMessagePrefix = function() end,
        SendAddonMessage = function(prefix, payload)
          if prefix == "WMRX" then
            operationPayload = payload
          end
        end,
      },
      bnetApi = {},
    }
    SendHandler.HandleSend(sender, {
      conversationKey = "wow::WOW::arthas-area52",
      target = "Arthas-Area52",
      displayName = "Arthas-Area52",
      guid = "Player-1",
      channel = "WOW",
      text = Protocol.BuildFallback("heart", "set", olderSource),
      reactionControl = {
        actorName = "Artio",
        sourceText = olderSource,
        operation = {
          type = "reaction",
          operation = "set",
          key = "heart",
          wireId = nil,
        },
      },
    }, function() end)

    local receiver = newReceiver(1400)
    local key = "wow::WOW::arthas-area52"
    local older = { kind = "user", direction = "out", text = olderSource, sentAt = 1200 }
    local newer = { kind = "user", direction = "out", text = newerSource, sentAt = 1250 }
    receiver.store.conversations[key] = {
      conversationKey = key,
      messages = { older, newer },
      unreadCount = 0,
      lastPreview = newerSource,
      lastActivityAt = 1250,
    }
    Router.HandleEvent(receiver, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = operationPayload,
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    Router.HandleEvent(receiver, "CHAT_MSG_WHISPER", {
      text = QuestLinkClassic.CanonicalizeForTransport(normalFallback),
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 9,
    })
    assert(older.reaction and older.reaction.key == "heart", "legacy reaction should target exact older quest ID")
    assert(newer.reaction == nil, "same-name newer quest with different ID must remain unchanged")
  end

  FlavorCompat.isClassic = savedClassic
end
