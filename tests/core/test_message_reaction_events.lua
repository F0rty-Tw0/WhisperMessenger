local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local MessageReactions = require("WhisperMessenger.Model.MessageReactions")
local Router = require("WhisperMessenger.Core.EventRouter")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local SoundPlayer = require("WhisperMessenger.Core.SoundPlayer")

local function newState(nowFn)
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = nowFn,
  }
end

local function putOutgoing(state, conversationKey, message, metadata)
  local conversation = {
    conversationKey = conversationKey,
    messages = { message },
    unreadCount = 0,
    lastPreview = message.text,
    lastActivityAt = message.sentAt,
  }
  for key, value in pairs(metadata or {}) do
    conversation[key] = value
  end
  state.store.conversations[conversationKey] = conversation
  return conversation
end

return function()
  local savedTimer = _G.C_Timer
  local savedInCombatLockdown = _G.InCombatLockdown
  _G.C_Timer = nil

  -- Identity metadata and normal WOW whispers pair in either order.
  do
    local state = newState(function()
      return 100
    end)
    local key = "wow::WOW::arthas-area52"
    Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = Protocol.EncodeIdentity("wire1", "first"),
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    local conversation = Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "first",
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 1,
    })
    assert(conversation and conversation.messages[1].wireId == "wire1", "WOW metadata-before-message should persist wire ID")

    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "second",
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 2,
    })
    assert(conversation.messages[2].wireId == nil, "message should wait for later identity metadata")
    Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = Protocol.EncodeIdentity("wire2", "second"),
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    assert(conversation.messages[2].wireId == "wire2", "WOW message-before-metadata should persist wire ID")
    assert(#conversation.messages == 2 and state.store.conversations[key] == conversation, "identity controls should not add messages")
  end

  -- Reaction metadata before normal WOW fallback converts without transcript effects.
  do
    local now = 200
    local state = newState(function()
      return now
    end)
    local key = "wow::WOW::arthas-area52"
    local target = { kind = "user", direction = "out", text = "Ready?", wireId = "target1", sentAt = 190 }
    local conversation = putOutgoing(state, key, target)
    local fallback = Protocol.BuildFallback("heart", "set", target.text)
    local operation = Protocol.EncodeReaction("set", "heart", target.wireId, target.text, fallback)

    local metadataResult = Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = operation,
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    assert(metadataResult == nil and target.reaction == nil, "reaction metadata alone should not mutate target")

    local result, meta = Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = fallback,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 3,
    })
    assert(result == conversation and meta and meta.reactionControl == true and meta.reactionChanged == true, "WOW control should convert")
    assert(
      state.availabilityByGUID["Player-1"] and state.availabilityByGUID["Player-1"].confirmedByWhisper == true,
      "converted incoming control should confirm whisper availability"
    )
    assert(#conversation.messages == 1 and conversation.unreadCount == 0, "converted control should not append or increment unread")
    assert(conversation.lastPreview == "Ready?" and conversation.lastActivityAt == 190, "converted control should not change preview or ordering")
    assert(
      target.reaction and target.reaction.key == "heart" and target.reaction.actorName == "Arthas-Area52",
      "event sender should be reaction actor"
    )
  end

  -- Saved regular-WOW controls retain a trailing space after the canonical fallback.
  do
    local fallback = Protocol.BuildFallback("thumbsup", "set", "kk")
    assert(fallback == "reacted :thumbsup: to: “kk”", "reaction metadata should fingerprint canonical fallback")

    local function runOrder(metadataFirst)
      local state = newState(function()
        return 250
      end)
      local key = "wow::WOW::catbury"
      local target = { kind = "user", direction = "out", text = "kk", wireId = "catbury1", sentAt = 240 }
      local conversation = putOutgoing(state, key, target)
      local operation = Protocol.EncodeReaction("set", "thumbsup", target.wireId, target.text, fallback)
      local function routeMetadata()
        return Router.HandleEvent(state, "CHAT_MSG_ADDON", {
          prefix = "WMRX",
          text = operation,
          channel = "WHISPER",
          playerName = "Catbury",
        })
      end
      local function routeFallback()
        return Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
          text = fallback .. " ",
          playerName = "Catbury",
          guid = "Player-Catbury",
          lineID = 4,
        })
      end

      if metadataFirst then
        routeMetadata()
        local result, meta = routeFallback()
        assert(
          result == conversation and meta and meta.reactionControl == true and meta.reactionChanged == true,
          "trailing-space WOW control should convert after metadata"
        )
      else
        local staged, stagedMeta = routeFallback()
        assert(
          staged == nil and stagedMeta and stagedMeta.reactionControl == true and stagedMeta.reactionStaged == true,
          "trailing-space WOW control should stage before metadata"
        )
        local result, meta = routeMetadata()
        assert(result == conversation and meta and meta.reactionChanged == true, "late metadata should convert trailing-space control")
      end

      assert(#conversation.messages == 1 and conversation.unreadCount == 0, "converted control should stay hidden")
      assert(target.reaction and target.reaction.key == "thumbsup" and target.reaction.actorName == "Catbury", "Catbury should be reaction actor")
    end

    runOrder(true)
    runOrder(false)
  end

  -- Normal fallback before metadata stages invisibly, then late metadata converts.
  do
    local now = 300
    local state = newState(function()
      return now
    end)
    local key = "wow::WOW::arthas-area52"
    local target = { kind = "user", direction = "out", text = "Again", wireId = "target2", sentAt = 290 }
    local conversation = putOutgoing(state, key, target)
    local fallback = Protocol.BuildFallback("wow", "set", target.text)

    local staged, stagedMeta = Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = fallback,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 4,
    })
    assert(
      staged == nil and stagedMeta and stagedMeta.reactionControl == true and stagedMeta.reactionStaged == true,
      "fallback should stage invisibly"
    )
    assert(
      state.availabilityByGUID["Player-1"] and state.availabilityByGUID["Player-1"].confirmedByWhisper == true,
      "staged incoming control should confirm whisper availability"
    )
    assert(#conversation.messages == 1 and conversation.unreadCount == 0, "staged fallback should have no conversation effects")

    local result, meta = Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = Protocol.EncodeReaction("set", "wow", target.wireId, target.text, fallback),
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    assert(result == conversation and meta and meta.reactionChanged == true, "late metadata should resolve staged fallback")
    assert(#conversation.messages == 1 and target.reaction and target.reaction.key == "wow", "resolved staged fallback should stay hidden")
  end
  -- WOW reaction correlation resolves base-name metadata to existing full-name conversation in either order.
  do
    local function runOrder(metadataFirst, addonName, fallbackName)
      local now = 350
      local state = newState(function()
        return now
      end)
      local key = "wow::WOW::friend-realm"
      local target = { kind = "user", direction = "out", text = "Alias target", wireId = "aliastarget", sentAt = 340 }
      local conversation = putOutgoing(state, key, target, {
        channel = "WOW",
        displayName = "Friend-Realm",
      })
      local fallback = Protocol.BuildFallback("heart", "set", target.text)
      local operation = Protocol.EncodeReaction("set", "heart", target.wireId, target.text, fallback)
      local result
      local meta

      if metadataFirst then
        result, meta = Router.HandleEvent(state, "CHAT_MSG_ADDON", {
          prefix = "WMRX",
          text = operation,
          channel = "WHISPER",
          playerName = addonName,
        })
        assert(result == nil and target.reaction == nil, "alias metadata should wait for fallback")

        result, meta = Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
          text = fallback,
          playerName = fallbackName,
          guid = "Player-alias",
          lineID = 6,
        })
      else
        result, meta = Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
          text = fallback,
          playerName = fallbackName,
          guid = "Player-alias",
          lineID = 7,
        })
        assert(result == nil and meta and meta.reactionStaged == true, "alias fallback should stage invisibly")
        result, meta = Router.HandleEvent(state, "CHAT_MSG_ADDON", {
          prefix = "WMRX",
          text = operation,
          channel = "WHISPER",
          playerName = addonName,
        })
      end

      assert(
        result == conversation and meta and meta.reactionControl == true and meta.reactionChanged == true,
        "alias reaction should convert ("
          .. addonName
          .. "/"
          .. fallbackName
          .. ", "
          .. (metadataFirst and "metadata-first" or "fallback-first")
          .. "), result="
          .. tostring(result)
          .. ", reactionChanged="
          .. tostring(target.reaction ~= nil)
      )
      assert(#conversation.messages == 1 and conversation.messages[1] == target, "alias control text should stay hidden")
      assert(
        target.direction == "out" and target.reaction and target.reaction.key == "heart" and target.reaction.actorName == "Friend-Realm",
        "alias reaction should update original outgoing message with stable actor"
      )
    end
    runOrder(true, "Friend", "Friend-Realm")
    runOrder(false, "Friend", "Friend-Realm")
    runOrder(true, "Friend-Realm", "Friend")
    runOrder(false, "Friend-Realm", "Friend")
  end

  -- Invalid/missing metadata degrades the readable fallback after exactly 15 seconds.
  do
    local now = 400
    local state = newState(function()
      return now
    end)
    local key = "wow::WOW::arthas-area52"
    local target = { kind = "user", direction = "out", text = "Visible", wireId = "target3", sentAt = 390 }
    local conversation = putOutgoing(state, key, target)
    Router.HandleEvent(state, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = "2|R|S|heart|target3|12345678|12345678",
      channel = "WHISPER",
      playerName = "Arthas-Area52",
    })
    local fallback = Protocol.BuildFallback("sad", "set", target.text)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = fallback,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 5,
    })
    assert(#conversation.messages == 1 and conversation.unreadCount == 0, "fallback should remain staged before expiry")
    now = 414
    MessageReactions.Expire(state, now)
    assert(#conversation.messages == 1, "fallback should remain hidden before 15 seconds")
    now = 415
    MessageReactions.Expire(state, now)
    assert(#conversation.messages == 2, "expired fallback should enter readable history")
    assert(conversation.messages[2].text == fallback, "degraded fallback should preserve normal whisper text")
    assert(
      conversation.unreadCount == 1 and conversation.lastPreview == fallback and conversation.lastActivityAt == 400,
      "degraded fallback should regain ordinary incoming effects"
    )
  end

  -- A delayed fallback is inserted by sentAt and cannot overwrite or evict
  -- an intervening newer message when retention is already at its cap.
  do
    local now = 500
    local state = newState(function()
      return now
    end)
    state.store.config.maxMessagesPerConversation = 2
    local key = "wow::WOW::arthas-area52"
    local target = { kind = "user", direction = "out", text = "Original", wireId = "target4", sentAt = 490 }
    local conversation = putOutgoing(state, key, target)
    local fallback = Protocol.BuildFallback("sad", "set", target.text)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = fallback,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 50,
    })

    now = 500
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "newer ordinary whisper",
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 51,
    })
    assert(
      conversation.lastPreview == "newer ordinary whisper" and conversation.lastActivityAt == 500,
      "same-second newer message should own activity metadata before degradation"
    )

    now = 515
    MessageReactions.Expire(state, now)
    assert(#conversation.messages == 2, "message cap should remain enforced after delayed insertion")
    assert(
      conversation.messages[1].text == fallback and conversation.messages[2].text == "newer ordinary whisper",
      "delayed fallback should insert before newer message"
    )
    assert(
      conversation.lastPreview == "newer ordinary whisper" and conversation.lastActivityAt == 500,
      "delayed fallback must not overwrite same-second newer preview or activity"
    )
    assert(
      conversation.lastIncomingPreview == "newer ordinary whisper" and conversation.lastIncomingAt == 500,
      "delayed fallback must not overwrite same-second newer incoming metadata"
    )
    assert(conversation.unreadCount == 2, "delayed fallback should still apply unread effect at actual degradation")
  end

  -- Delayed fallback older than a newer DND status must not clear that status.
  do
    local now = 550
    local state = newState(function()
      return now
    end)
    local key = "wow::WOW::arthas-area52"
    local target = { kind = "user", direction = "out", text = "Status target", wireId = "status-target", sentAt = 540 }
    local conversation = putOutgoing(state, key, target)
    local fallback = Protocol.BuildFallback("heart", "set", target.text)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = fallback,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 52,
    })
    now = 555
    Router.HandleEvent(state, "CHAT_MSG_DND", {
      text = "Do not disturb",
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 53,
    })
    assert(conversation.activeStatus and conversation.activeStatus.eventName == "CHAT_MSG_DND", "newer DND should be active before expiry")
    now = 565
    MessageReactions.Expire(state, now)
    assert(conversation.activeStatus and conversation.activeStatus.text == "Do not disturb", "older delayed fallback must preserve newer DND status")
  end

  -- A delayed fallback newer than DND clears it even when later transcript
  -- activity means the fallback is not the newest retained message.
  do
    local now = 600
    local state = newState(function()
      return now
    end)
    local key = "wow::WOW::arthas-area52"
    local target = { kind = "user", direction = "out", text = "Inverse status target", wireId = "status-target-2", sentAt = 590 }
    local conversation = putOutgoing(state, key, target)
    Router.HandleEvent(state, "CHAT_MSG_DND", {
      text = "Earlier DND",
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 60,
    })
    now = 605
    local fallback = Protocol.BuildFallback("heart", "set", target.text)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = fallback,
      playerName = "Arthas-Area52",
      guid = "Player-1",
      lineID = 61,
    })
    now = 610
    Store.AppendOutgoing(state.store, key, {
      kind = "user",
      direction = "out",
      text = "newer transcript activity",
      sentAt = now,
      lineID = 62,
    })
    assert(conversation.activeStatus and conversation.activeStatus.text == "Earlier DND", "staged fallback should not clear DND before degradation")
    now = 620
    MessageReactions.Expire(state, now)
    assert(conversation.activeStatus == nil, "fallback newer than DND should clear it regardless of later transcript activity")
    assert(
      conversation.lastPreview == "newer transcript activity" and conversation.lastActivityAt == 610,
      "clearing older DND must preserve newer transcript metadata"
    )
  end

  -- Battle.net uses account-scoped sender identity and equivalent conversion.
  -- Battle.net identity metadata can arrive before the first stored conversation.
  do
    local state = newState(function()
      return 450
    end)
    local accountInfo = {
      bnetAccountID = 77,
      battleTag = "Jaina#1234",
      gameAccountInfo = { characterName = "Jaina", realmName = "Proudmoore" },
    }
    Router.HandleEvent(state, "BN_CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = Protocol.EncodeIdentity("bnwire", "first BN"),
      channel = "WHISPER",
      bnetAccountID = 77,
    })
    local conversation = Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", {
      text = "first BN",
      playerName = "Jaina",
      channel = "BN",
      bnetAccountID = 77,
      accountInfo = accountInfo,
      lineID = 55,
    })
    assert(conversation and conversation.messages[1].wireId == "bnwire", "BN identity metadata should pair before first conversation exists")
  end

  do
    local state = newState(function()
      return 500
    end)
    local key = "bnet::BN::jaina#1234"
    local accountInfo = {
      bnetAccountID = 77,
      battleTag = "Jaina#1234",
      gameAccountInfo = { characterName = "Jaina", realmName = "Proudmoore" },
    }
    local target = { kind = "user", direction = "out", text = "BN original", wireId = "bntarget", sentAt = 490, channel = "BN" }
    local conversation = putOutgoing(state, key, target, { channel = "BN", bnetAccountID = 77, battleTag = "Jaina#1234" })
    local fallback = Protocol.BuildFallback("gg", "set", target.text)

    Router.HandleEvent(state, "BN_CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = Protocol.EncodeReaction("set", "gg", target.wireId, target.text, fallback),
      channel = "WHISPER",
      bnetAccountID = 77,
      accountInfo = accountInfo,
    })
    local result, meta = Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", {
      text = fallback,
      playerName = "Jaina",
      channel = "BN",
      bnetAccountID = 77,
      accountInfo = accountInfo,
      lineID = 6,
    })
    assert(result == conversation and meta and meta.reactionControl == true, "BN control should convert")
    assert(#conversation.messages == 1 and target.reaction and target.reaction.key == "gg", "BN converted fallback should stay hidden")
    assert(target.reaction.actorName == "Jaina#1234", "BN actor should derive from event-resolved identity")
  end

  -- Live BN addon metadata and normal whispers correlate in either arrival
  -- order, including bnet-only and unresolved metadata fallbacks.
  do
    local function runLiveBNetReaction(scenario)
      local state = newState(function()
        return scenario.now
      end)
      local key = "bnet::BN::jaina#1234"
      local accountInfo = {
        bnetAccountID = 77,
        battleTag = "Jaina#1234",
        isOnline = true,
        gameAccountInfo = {
          gameAccountID = 9001,
          playerGuid = "Player-1-JAINA",
          characterName = "Jaina",
          realmName = "Proudmoore",
        },
      }
      local resolutions = {
        resolved = {
          gameAccountInfo = accountInfo.gameAccountInfo,
          accountInfo = accountInfo,
          reactionKey = "heart",
          actorName = "Jaina#1234",
        },
        unresolved = {
          reactionKey = "thumbsup",
          fallback = "reacted :thumbsup: to: “kk”",
        },
      }
      local fallbackAccounts = { resolved = accountInfo, ["bnet-only"] = { bnetAccountID = 77, battleTag = "Jaina#1234", isOnline = true } }
      local resolution = resolutions[scenario.metadataResolution]
      state.bnetApi = {
        GetGameAccountInfoByID = function(gameAccountID)
          assert(gameAccountID == 9001, "live BN addon should resolve sender gameAccountID")
          return resolution.gameAccountInfo
        end,
        GetAccountInfoByID = function(bnetAccountID)
          assert(bnetAccountID == 77, "normal live BN whisper should resolve with bnetAccountID")
          return fallbackAccounts[scenario.fallbackAccount]
        end,
      }
      if resolution.accountInfo then
        state.bnetApi.GetAccountInfoByGUID = function(guid)
          assert(guid == "Player-1-JAINA", "live BN addon should resolve game-account player GUID")
          return resolution.accountInfo
        end
      end

      local target = {
        kind = "user",
        direction = "out",
        text = scenario.text,
        wireId = scenario.wireId,
        sentAt = scenario.now - 10,
        channel = "BN",
      }
      local conversation =
        putOutgoing(state, key, target, { channel = "BN", bnetAccountID = 77, battleTag = "Jaina#1234", displayName = "Jaina#1234" })
      local fallback = resolution.fallback or Protocol.BuildFallback(resolution.reactionKey, "set", target.text)
      if resolution.fallback then
        assert(Protocol.BuildFallback(resolution.reactionKey, "set", target.text) == fallback, "BN fallback should remain user-visible text")
      end
      local metadata = Protocol.EncodeReaction("set", resolution.reactionKey, target.wireId, target.text, fallback)

      local function routeMetadata()
        EventBridge.RouteLiveEvent(state, nil, "BN_CHAT_MSG_ADDON", "WMRX", metadata, "WHISPER", 9001)
      end
      local function routeFallback()
        EventBridge.RouteLiveEvent(
          state,
          nil,
          "CHAT_MSG_BN_WHISPER",
          fallback,
          "Jaina",
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          nil,
          scenario.lineID,
          "Player-1-JAINA",
          77
        )
      end

      if scenario.arrivalOrder == "metadata-first" then
        routeMetadata()
        routeFallback()
      else
        routeFallback()
        routeMetadata()
      end

      assert(
        target.reaction
          and target.reaction.key == resolution.reactionKey
          and (not resolution.actorName or target.reaction.actorName == resolution.actorName),
        scenario.name .. " should apply to the original outgoing message"
      )
      assert(
        #conversation.messages == 1 and (scenario.fallbackAccount ~= "bnet-only" or conversation.messages[1] == target),
        scenario.name .. " fallback should remain hidden"
      )
    end

    local scenarios = {
      {
        name = "resolved metadata before fallback",
        now = 525,
        metadataResolution = "resolved",
        fallbackAccount = "resolved",
        arrivalOrder = "metadata-first",
        text = "BN metadata first",
        wireId = "bnlive1",
        lineID = 61,
      },
      {
        name = "resolved fallback before metadata",
        now = 525,
        metadataResolution = "resolved",
        fallbackAccount = "resolved",
        arrivalOrder = "fallback-first",
        text = "BN fallback first",
        wireId = "bnlive2",
        lineID = 62,
      },
      {
        name = "resolved metadata with bnet-only fallback",
        now = 530,
        metadataResolution = "resolved",
        fallbackAccount = "bnet-only",
        arrivalOrder = "metadata-first",
        text = "BN resolved metadata target",
        wireId = "bnresolved",
        lineID = 63,
      },
      {
        name = "unresolved metadata before fallback",
        now = 535,
        metadataResolution = "unresolved",
        fallbackAccount = "resolved",
        arrivalOrder = "metadata-first",
        text = "kk",
        wireId = "bnunresolved1",
        lineID = 63,
      },
      {
        name = "unresolved fallback before metadata",
        now = 535,
        metadataResolution = "unresolved",
        fallbackAccount = "resolved",
        arrivalOrder = "fallback-first",
        text = "kk",
        wireId = "bnunresolved2",
        lineID = 64,
      },
    }

    for _, scenario in ipairs(scenarios) do
      runLiveBNetReaction(scenario)
    end
  end

  -- Unresolved game-account metadata must not correlate with an equal-valued
  -- BNet account ID from a different sender.
  do
    local now = 540
    local state = newState(function()
      return now
    end)
    local key = "bnet::BN::velen#1234"
    local accountInfo = {
      bnetAccountID = 77,
      battleTag = "Velen#1234",
      isOnline = true,
      gameAccountInfo = {
        playerGuid = "Player-1-VELEN",
        characterName = "Velen",
        realmName = "Draenor",
      },
    }
    state.bnetApi = {
      GetGameAccountInfoByID = function(gameAccountID)
        assert(gameAccountID == 77, "live BN addon should retain unresolved colliding game-account ID")
        return nil
      end,
      GetAccountInfoByID = function(bnetAccountID)
        assert(bnetAccountID == 77, "normal live BN whisper should resolve colliding BNet account ID")
        return accountInfo
      end,
    }
    local target = {
      kind = "user",
      direction = "out",
      text = "numeric collision",
      wireId = "bncollision",
      sentAt = 530,
      channel = "BN",
    }
    local conversation = putOutgoing(state, key, target, { channel = "BN", bnetAccountID = 77, battleTag = "Velen#1234", displayName = "Velen#1234" })
    local fallback = Protocol.BuildFallback("heart", "set", target.text)
    local metadata = Protocol.EncodeReaction("set", "heart", target.wireId, target.text, fallback)

    EventBridge.RouteLiveEvent(state, nil, "BN_CHAT_MSG_ADDON", "WMRX", metadata, "WHISPER", 77)
    EventBridge.RouteLiveEvent(state, nil, "CHAT_MSG_BN_WHISPER", fallback, "Velen", nil, nil, nil, nil, nil, nil, nil, nil, 65, "Player-1-VELEN", 77)

    assert(target.reaction == nil, "unresolved game-account metadata must not mutate colliding BNet sender")
    assert(#conversation.messages == 1, "colliding BNet fallback should remain staged pending its own metadata")
    now = 555
    MessageReactions.Expire(state, now)
    assert(
      target.reaction == nil and conversation.messages[2] and conversation.messages[2].text == fallback,
      "colliding BNet fallback should become readable without applying game-account metadata"
    )
  end

  -- Group reaction packets on whisper transports are never correlated or
  -- allowed to mutate the whisper reaction queues.
  do
    local payload = assert(
      Protocol.EncodeGroupReaction(
        "set",
        "heart",
        nil,
        "spoof target",
        Protocol.BuildGroupFallback("heart", "set", "spoof target"),
        "Player-spoof",
        "Spoof-Realm"
      )
    )
    local wowState = newState(function()
      return 550
    end)
    local wowKey = "wow::WOW::spoof-realm"
    local wowTarget = { kind = "user", direction = "out", text = "spoof target", sentAt = 540 }
    putOutgoing(wowState, wowKey, wowTarget)
    Router.HandleEvent(wowState, "CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = payload,
      channel = "WHISPER",
      playerName = "Spoof-Realm",
    })
    assert(wowTarget.reaction == nil and wowState.messageReactionRuntime == nil, "WOW whisper must ignore spoofed group reaction")

    local bnState = newState(function()
      return 550
    end)
    local bnKey = "bnet::BN::spoof#1234"
    local bnTarget = { kind = "user", direction = "out", text = "spoof target", sentAt = 540, channel = "BN" }
    putOutgoing(bnState, bnKey, bnTarget, { channel = "BN", bnetAccountID = 88, battleTag = "Spoof#1234" })
    Router.HandleEvent(bnState, "BN_CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = payload,
      channel = "WHISPER",
      bnetAccountID = 88,
    })
    assert(bnTarget.reaction == nil and bnState.messageReactionRuntime == nil, "BN whisper must ignore spoofed group reaction")
  end
  -- EventBridge suppresses all incoming/outgoing side effects for converted controls.
  do
    local now = 600
    local state = newState(function()
      return now
    end)
    local key = "wow::WOW::arthas-area52"
    local target = { kind = "user", direction = "out", text = "Bridge", wireId = "bridge1", sentAt = 590 }
    local conversation = putOutgoing(state, key, target)
    state.accountState = {
      settings = {
        playSoundOnWhisper = true,
        autoOpenIncoming = true,
        autoOpenOutgoing = true,
      },
    }
    state.chatApi = {}
    state.bnetApi = {}
    local sounds, incomingOpens, outgoingOpens, refreshes = 0, 0, 0, 0
    local originalPlay = SoundPlayer.Play
    rawset(SoundPlayer, "Play", function()
      sounds = sounds + 1
    end)
    state.onAutoOpen = function()
      incomingOpens = incomingOpens + 1
    end
    state.onAutoOpenOutgoing = function()
      outgoingOpens = outgoingOpens + 1
    end
    rawset(_G, "InCombatLockdown", function()
      return false
    end)
    local function refreshWindow()
      refreshes = refreshes + 1
    end

    local fallback = Protocol.BuildFallback("question", "set", target.text)
    EventBridge.RouteLiveEvent(
      state,
      refreshWindow,
      "CHAT_MSG_WHISPER",
      fallback,
      "Arthas-Area52",
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      7,
      "Player-1"
    )
    assert(sounds == 0 and incomingOpens == 0 and refreshes == 0, "staged control should have no sound, auto-open, or refresh")
    assert(state.lastIncomingWhisperKey == nil, "staged control should not alter reply target")

    EventBridge.RouteLiveEvent(
      state,
      refreshWindow,
      "CHAT_MSG_ADDON",
      "WMRX",
      Protocol.EncodeReaction("set", "question", target.wireId, target.text, fallback),
      "WHISPER",
      "Arthas-Area52"
    )
    assert(target.reaction and target.reaction.key == "question", "late bridge metadata should apply reaction")
    assert(sounds == 0 and incomingOpens == 0 and outgoingOpens == 0, "converted control should keep notification and open effects suppressed")
    assert(refreshes == 1, "converted control should refresh only affected conversation")
    assert(#conversation.messages == 1 and conversation.lastActivityAt == 590, "bridge conversion should not change transcript or ordering")

    local degradedFallback = Protocol.BuildFallback("heart", "set", target.text)
    now = 610
    EventBridge.RouteLiveEvent(
      state,
      refreshWindow,
      "CHAT_MSG_WHISPER",
      degradedFallback,
      "Arthas-Area52",
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      nil,
      8,
      "Player-1"
    )
    assert(sounds == 0 and incomingOpens == 0 and refreshes == 1, "unmatched fallback should stay effect-free during TTL")
    now = 625
    MessageReactions.Expire(state, now)
    assert(sounds == 1 and incomingOpens == 1 and refreshes == 2, "expired fallback should regain ordinary sound, auto-open, and refresh")
    assert(state.lastIncomingWhisperKey == key, "expired fallback should become reply target")
    assert(#conversation.messages == 2 and conversation.messages[2].text == degradedFallback, "expired fallback should enter readable history")

    rawset(SoundPlayer, "Play", originalPlay)
  end

  _G.C_Timer = savedTimer
  rawset(_G, "InCombatLockdown", savedInCombatLockdown)
end
