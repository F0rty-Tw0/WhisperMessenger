local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local Router = require("WhisperMessenger.Core.EventRouter")
local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local reactionHandlerLoaded, ReactionHandler = pcall(require, "WhisperMessenger.Core.Bootstrap.ReactionHandler")
local GroupSendPolicy = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")

local function newStore()
  return Store.New({
    maxMessagesPerConversation = 20,
    maxConversations = 10,
    messageMaxAge = 86400,
    conversationMaxAge = 86400,
  })
end

return function()
  assert(reactionHandlerLoaded, "ReactionHandler module should load before send integration can pass")

  local savedUnitName = _G.UnitName
  local savedInCombatLockdown = _G.InCombatLockdown
  rawset(_G, "UnitName", function(unit)
    assert(unit == "player")
    return "Artio"
  end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)

  -- Ordinary WOW whispers synchronously send normal text, then identity metadata.
  do
    local dispatches = {}
    local runtime = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 100
      end,
      chatApi = {
        SendChatMessage = function(text, chatType, _, target)
          table.insert(dispatches, { transport = "normal", text = text, chatType = chatType, target = target })
        end,
        RegisterAddonMessagePrefix = function() end,
        SendAddonMessage = function(prefix, payload, channel, target)
          table.insert(dispatches, { transport = "addon", prefix = prefix, payload = payload, channel = channel, target = target })
        end,
      },
      bnetApi = {},
    }
    local conversationKey = "wow::WOW::arthas-area52"
    local accepted = SendHandler.HandleSend(runtime, {
      conversationKey = conversationKey,
      target = "Arthas-Area52",
      displayName = "Arthas-Area52",
      guid = "Player-1",
      channel = "WOW",
      text = "ordinary whisper",
    }, function() end)

    assert(accepted == true, "ordinary WOW whisper should send")
    assert(#dispatches == 2, "ordinary send should dispatch normal whisper and identity metadata")
    assert(dispatches[1].transport == "normal" and dispatches[1].text == "ordinary whisper", "normal whisper must remain first and synchronous")
    assert(dispatches[2].transport == "addon" and dispatches[2].prefix == "WMRX", "identity should use WMRX")
    local identity = Protocol.Decode(dispatches[2].payload)
    assert(identity and identity.type == "identity", "ordinary send should emit identity metadata")

    local queue = runtime.pendingOutgoing[conversationKey]
    assert(queue and queue[1] and queue[1].wireId == identity.wireId, "pending ordinary send should retain shared wire ID")

    local conversation = Router.HandleEvent(runtime, "CHAT_MSG_WHISPER_INFORM", {
      text = "ordinary whisper",
      playerName = "Arthas-Area52",
      guid = "Player-1",
      channel = "WOW",
      lineID = 1,
    })
    assert(conversation and conversation.messages[1].wireId == identity.wireId, "outgoing inform should persist pending wire ID")
  end

  -- Reaction fallback and metadata send from one callback; inform confirms state.
  do
    local dispatches = {}
    local runtime = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 200
      end,
      chatApi = {
        SendChatMessage = function(text, chatType, _, target)
          table.insert(dispatches, { transport = "normal", text = text, chatType = chatType, target = target })
        end,
        RegisterAddonMessagePrefix = function() end,
        SendAddonMessage = function(prefix, payload, channel, target)
          table.insert(dispatches, { transport = "addon", prefix = prefix, payload = payload, channel = channel, target = target })
        end,
      },
      bnetApi = {},
    }
    local conversationKey = "wow::WOW::arthas-area52"
    local targetMessage = {
      kind = "user",
      direction = "in",
      text = "Ready?",
      wireId = "target1",
      sentAt = 190,
      playerName = "Arthas-Area52",
    }
    runtime.store.conversations[conversationKey] = {
      conversationKey = conversationKey,
      messages = { targetMessage },
      unreadCount = 1,
      lastPreview = targetMessage.text,
      lastActivityAt = targetMessage.sentAt,
    }
    local contact = {
      conversationKey = conversationKey,
      displayName = "Arthas-Area52",
      guid = "Player-1",
      channel = "WOW",
    }

    local accepted = ReactionHandler.HandleReact(runtime, contact, targetMessage, "heart", function() end)
    assert(accepted == true, "eligible reaction should send")
    assert(targetMessage.reaction == nil, "reaction should not mutate optimistically")
    assert(#dispatches == 2 and dispatches[1].transport == "normal", "reaction should send one normal fallback first")
    assert(dispatches[2].prefix == "WMRX", "reaction metadata should use WMRX")
    local operation = Protocol.Decode(dispatches[2].payload)
    assert(operation and operation.type == "reaction" and operation.operation == "set", "reaction metadata should encode set")
    assert(operation.key == "heart" and operation.wireId == "target1", "reaction metadata should target requested key and wire ID")
    assert(#dispatches[1].text <= 255 and string.find(dispatches[1].text, ":heart:", 1, true), "normal fallback should be readable and capped")

    local beforeCount = #runtime.store.conversations[conversationKey].messages
    local conversation, meta = Router.HandleEvent(runtime, "CHAT_MSG_WHISPER_INFORM", {
      text = dispatches[1].text,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      channel = "WOW",
      lineID = 2,
    })
    assert(conversation and meta and meta.reactionControl == true and meta.reactionChanged == true, "inform should confirm reaction control")
    assert(
      runtime.availabilityByGUID["Player-1"] and runtime.availabilityByGUID["Player-1"].confirmedByWhisper == true,
      "local reaction inform should confirm target availability"
    )
    assert(#conversation.messages == beforeCount, "confirmed reaction fallback should not enter history")
    assert(targetMessage.reaction and targetMessage.reaction.key == "heart", "inform should apply reaction to original incoming message")
    assert(targetMessage.reaction.actorName == "Artio", "local event-confirmed reaction should store local actor")

    dispatches = {}
    assert(ReactionHandler.HandleReact(runtime, contact, targetMessage, "question", function() end) == true, "different key should send replacement")
    Router.HandleEvent(runtime, "CHAT_MSG_WHISPER_INFORM", {
      text = dispatches[1].text,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      channel = "WOW",
      lineID = 3,
    })
    assert(targetMessage.reaction and targetMessage.reaction.key == "question", "different key should replace after inform")

    dispatches = {}
    assert(ReactionHandler.HandleReact(runtime, contact, targetMessage, "question", function() end) == true, "same key should send remove")
    local remove = Protocol.Decode(dispatches[2].payload)
    assert(remove and remove.operation == "remove", "same selected key should encode remove")
    Router.HandleEvent(runtime, "CHAT_MSG_WHISPER_INFORM", {
      text = dispatches[1].text,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      channel = "WOW",
      lineID = 4,
    })
    assert(targetMessage.reaction == nil, "remove should apply after inform")
  end

  -- Group reactions route only through the injected group policy and display pending after full acceptance.
  do
    local normalCalls = 0
    local addonCalls = 0
    local refreshes = 0
    local conversationKey = "party::artio-area52"
    local runtime = {
      localProfileId = "artio-area52",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      now = function()
        return 250
      end,
      chatApi = {
        SendChatMessage = function()
          error("group reaction must not use whisper chat API")
        end,
        SendAddonMessage = function()
          error("group reaction must not use whisper addon API")
        end,
      },
      bnetApi = {
        SendWhisper = function()
          error("group reaction must not use BNet whisper API")
        end,
        SendGameData = function()
          error("group reaction must not use BNet addon API")
        end,
      },
    }
    local targetMessage = {
      kind = "user",
      direction = "in",
      channel = "PARTY",
      text = "Group message",
      wireId = "party1",
      guid = "Player-1",
      playerName = "Thrall",
    }
    local groupConversation = {
      conversationKey = conversationKey,
      displayName = "Thrall",
      channel = "PARTY",
      guid = "Party-Current",
    }
    local contact = {
      conversationKey = "party::PARTY::snapshot",
      displayName = "Thrall",
      channel = "PARTY",
      conversation = groupConversation,
    }
    local policy = GroupSendPolicy.Create({
      runtime = runtime,
      chatGateway = {
        CanSend = function()
          return true
        end,
        Send = function(_, receivedConversation, text)
          normalCalls = normalCalls + 1
          assert(receivedConversation == groupConversation, "group reactions must send through the current underlying conversation")
          assert(string.find(text, "Artio", 1, true) == nil, "group fallback must not expose actor")
        end,
      },
      addonComm = {
        SendGroup = function(_, prefix, payload, channel)
          addonCalls = addonCalls + 1
          assert(prefix == "WMRX" and channel == "PARTY", "group metadata must use WMRX on party")
          local operation = Protocol.Decode(payload)
          assert(operation and operation.type == "groupReaction" and operation.targetGuid == "Player-1", "group metadata should use G operation")
          return true
        end,
      },
    })
    assert(ReactionHandler.HandleReact(runtime, contact, targetMessage, "heart", function()
      refreshes = refreshes + 1
    end, policy) == true, "group reaction should accept through group policy")
    assert(normalCalls == 1 and addonCalls == 1, "group reaction should use one normal and one addon group dispatch")
    assert(targetMessage._pendingReaction and targetMessage._pendingReaction.operation == "set", "accepted group reaction should begin pending badge")

    local rejected = GroupSendPolicy.Create({
      runtime = runtime,
      chatGateway = {
        CanSend = function()
          return false
        end,
      },
      addonComm = {
        SendGroup = function()
          return true
        end,
      },
    })
    targetMessage._pendingReaction = nil
    assert(
      ReactionHandler.HandleReact(runtime, contact, targetMessage, "laugh", function() end, rejected) == false,
      "unsendable group reaction should reject"
    )
    assert(targetMessage._pendingReaction == nil, "rejected group reaction should leave no pending badge")
  end

  -- Group-channel reactions must be rejected before either transport dispatch.
  do
    local dispatches = {}
    local conversationKey = "party::PARTY::Arthas"
    local runtime = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 300
      end,
      chatApi = {
        SendChatMessage = function(text, chatType, _, target)
          table.insert(dispatches, { transport = "normal", text = text, chatType = chatType, target = target })
        end,
        RegisterAddonMessagePrefix = function() end,
        SendAddonMessage = function(prefix, payload, channel, target)
          table.insert(dispatches, { transport = "addon", prefix = prefix, payload = payload, channel = channel, target = target })
        end,
      },
      bnetApi = {},
    }
    local targetMessage = {
      kind = "user",
      direction = "in",
      channel = "PARTY",
      text = "Group message",
      wireId = "party-target",
      sentAt = 290,
      playerName = "Arthas",
    }
    runtime.store.conversations[conversationKey] = {
      conversationKey = conversationKey,
      messages = { targetMessage },
      unreadCount = 1,
      lastPreview = targetMessage.text,
      lastActivityAt = targetMessage.sentAt,
    }
    local contact = {
      conversationKey = conversationKey,
      displayName = "Arthas",
      guid = "Player-1",
      channel = "WOW",
    }

    local accepted = ReactionHandler.HandleReact(runtime, contact, targetMessage, "heart", function() end)
    assert(accepted == false, "PARTY reaction should be rejected")
    assert(#dispatches == 0, "PARTY reaction should not dispatch chat or addon messages")
  end

  -- WOW-message reactions must reject a PARTY-selected contact before either transport dispatch.
  do
    local dispatches = {}
    local conversationKey = "wow::WOW::Arthas"
    local runtime = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 400
      end,
      chatApi = {
        SendChatMessage = function(text, chatType, _, target)
          table.insert(dispatches, { transport = "normal", text = text, chatType = chatType, target = target })
        end,
        RegisterAddonMessagePrefix = function() end,
        SendAddonMessage = function(prefix, payload, channel, target)
          table.insert(dispatches, { transport = "addon", prefix = prefix, payload = payload, channel = channel, target = target })
        end,
      },
      bnetApi = {},
    }
    local targetMessage = {
      kind = "user",
      direction = "in",
      channel = "WOW",
      text = "Whisper message",
      wireId = "wow-target",
      sentAt = 390,
      playerName = "Arthas",
    }
    runtime.store.conversations[conversationKey] = {
      conversationKey = conversationKey,
      messages = { targetMessage },
      unreadCount = 1,
      lastPreview = targetMessage.text,
      lastActivityAt = targetMessage.sentAt,
    }
    local contact = {
      conversationKey = conversationKey,
      displayName = "Arthas",
      guid = "Player-1",
      channel = "PARTY",
    }

    local accepted = ReactionHandler.HandleReact(runtime, contact, targetMessage, "heart", function() end)
    assert(accepted == false, "WOW message with PARTY contact should be rejected")
    assert(#dispatches == 0, "WOW message with PARTY contact should not dispatch chat or addon messages")
  end

  -- Battle.net uses equivalent normal and WMRX transports; failed send stays unchanged.
  do
    local normalCalls = {}
    local addonCalls = {}
    local failSend = false
    local accountInfo = {
      bnetAccountID = 77,
      battleTag = "Jaina#1234",
      gameAccountInfo = {
        gameAccountID = 9001,
        characterName = "Jaina",
        realmName = "Proudmoore",
      },
    }
    local runtime = {
      localProfileId = "me",
      store = newStore(),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 300
      end,
      chatApi = {
        RegisterAddonMessagePrefix = function() end,
      },
      bnetApi = {
        SendWhisper = function(bnetAccountID, text)
          if failSend then
            error("simulated BN failure")
          end
          table.insert(normalCalls, { bnetAccountID = bnetAccountID, text = text })
        end,
        SendGameData = function(gameAccountID, prefix, payload)
          table.insert(addonCalls, { gameAccountID = gameAccountID, prefix = prefix, payload = payload })
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
    local conversationKey = "bnet::BN::jaina#1234"
    local targetMessage = {
      kind = "user",
      direction = "in",
      text = "BN target",
      wireId = "bntarget",
      sentAt = 290,
      playerName = "Jaina#1234",
      channel = "BN",
      bnetAccountID = 77,
    }
    runtime.store.conversations[conversationKey] = {
      conversationKey = conversationKey,
      channel = "BN",
      battleTag = "Jaina#1234",
      bnetAccountID = 77,
      messages = { targetMessage },
      unreadCount = 0,
      lastPreview = targetMessage.text,
      lastActivityAt = targetMessage.sentAt,
    }
    local contact = {
      conversationKey = conversationKey,
      displayName = "Jaina#1234",
      battleTag = "Jaina#1234",
      channel = "BN",
      bnetAccountID = 77,
    }

    assert(ReactionHandler.HandleReact(runtime, contact, targetMessage, "gg", function() end) == true, "BN reaction should send")
    assert(#normalCalls == 1 and normalCalls[1].bnetAccountID == 77, "BN normal fallback should use bnetAccountID")
    assert(
      normalCalls[1].text == Protocol.BuildGroupFallback("gg", "set", targetMessage.text),
      "BN whisper fallback should match group layout without local actor"
    )
    assert(
      #addonCalls == 1 and addonCalls[1].gameAccountID == 9001 and addonCalls[1].prefix == "WMRX",
      "BN reaction metadata should use resolved gameAccountID"
    )
    local operation = Protocol.Decode(addonCalls[1].payload)
    assert(operation and operation.key == "gg", "BN reaction metadata should decode equivalently")

    local conversation, meta = Router.HandleEvent(runtime, "CHAT_MSG_BN_WHISPER_INFORM", {
      text = normalCalls[1].text,
      playerName = "Jaina",
      channel = "BN",
      bnetAccountID = 77,
      accountInfo = accountInfo,
      lineID = 10,
    })
    assert(conversation and meta and meta.reactionControl == true, "BN inform should consume reaction control")
    assert(targetMessage.reaction and targetMessage.reaction.key == "gg", "BN inform should apply reaction")

    targetMessage.reaction = nil
    failSend = true
    normalCalls = {}
    addonCalls = {}
    local failed = ReactionHandler.HandleReact(runtime, contact, targetMessage, "laugh", function() end)
    assert(failed == false, "throwing BN transport should report send failure")
    assert(targetMessage.reaction == nil, "failed BN reaction should leave target unchanged")
    assert(#addonCalls == 0, "failed normal fallback should not send hidden metadata")
  end

  -- A group policy may synchronously confirm its reaction control; the handler
  -- must not install a badge after that confirmation.
  do
    local refreshes = 0
    local runtime = {
      localPlayerName = "Artio",
      now = function()
        return 500
      end,
    }
    local message = {
      kind = "user",
      direction = "in",
      channel = "PARTY",
      text = "Group message",
      wireId = "party-target",
    }
    local control = { confirmed = true }
    local policy = {
      sendReaction = function(conversation, target, key, operation, actorName, pendingToken)
        assert(conversation.channel == "PARTY" and target == message, "handler must send selected group target")
        assert(
          key == "heart" and operation == "set" and actorName == "Artio" and pendingToken ~= nil,
          "handler must pass exact reaction control inputs"
        )
        return true, control
      end,
    }

    assert(ReactionHandler.HandleReact(runtime, { channel = "PARTY", conversationKey = "party::current" }, message, "heart", function()
      refreshes = refreshes + 1
    end, policy) == true, "synchronously confirmed group reaction must remain accepted")
    assert(message._pendingReaction == nil, "synchronously confirmed group reaction must not leave a pending badge")
    assert(refreshes == 1, "accepted synchronous confirmation should refresh once")
  end

  -- Competitive content rejects WOW, BN, and group reactions before a token,
  -- local pending state, or either transport can be touched.
  do
    local groupCalls = 0
    local runtime = {
      localPlayerName = "Artio",
      isCompetitiveContent = function()
        return true
      end,
      chatApi = {
        SendChatMessage = function()
          error("competitive WOW must not send")
        end,
        SendAddonMessage = function()
          error("competitive WOW must not send metadata")
        end,
      },
      bnetApi = {
        SendWhisper = function()
          error("competitive BN must not send")
        end,
        SendGameData = function()
          error("competitive BN must not send metadata")
        end,
      },
    }
    local policy = {
      sendReaction = function()
        groupCalls = groupCalls + 1
        return true
      end,
    }

    for _, channel in ipairs({ "WOW", "BN", "PARTY" }) do
      local message = {
        kind = "user",
        direction = "in",
        channel = channel,
        text = "target",
        wireId = channel .. "-target",
      }
      assert(
        ReactionHandler.HandleReact(
          runtime,
          { channel = channel, conversationKey = channel .. "::current" },
          message,
          "heart",
          function() end,
          policy
        ) == false,
        "competitive " .. channel .. " reaction must reject"
      )
      assert(message._pendingReaction == nil, "competitive " .. channel .. " reaction must not show pending")
    end
    assert(runtime.messageReactionPendingSequence == nil, "competitive reactions must reject before allocating pending tokens")
    assert(groupCalls == 0, "competitive group reaction must not call group policy")
  end

  rawset(_G, "UnitName", savedUnitName)
  rawset(_G, "InCombatLockdown", savedInCombatLockdown)
end
