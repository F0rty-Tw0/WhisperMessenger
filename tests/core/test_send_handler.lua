local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Availability = require("WhisperMessenger.Transport.Availability")
local Store = require("WhisperMessenger.Model.ConversationStore")
local Trace = require("WhisperMessenger.Core.Trace")

return function()
  local sentMessages = {}
  local refreshCalls = 0
  local savedInCombatLockdown = _G.InCombatLockdown
  local savedBNSendWhisper = _G.BNSendWhisper
  rawset(_G, "InCombatLockdown", function()
    return false
  end)

  local runtime = {
    sendStatusByConversation = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
    localProfileId = "me",
    chatApi = {
      SendChatMessage = function(text, chatType, languageID, target)
        table.insert(sentMessages, { text = text, target = target })
      end,
    },
    bnetApi = {
      GetNumFriends = function()
        return 2
      end,
      GetFriendAccountInfo = function(friendIndex)
        if friendIndex == 1 then
          return { bnetAccountID = 77, battleTag = "Jaina#1234", isOnline = true }
        end
        if friendIndex == 2 then
          return { bnetAccountID = 99, battleTag = "Thrall#1234", isOnline = true }
        end
        return nil
      end,
    },
    -- Stub fields used by EventRouter.RecordPendingSend
    store = Store.New({
      maxMessagesPerConversation = 20,
      maxConversations = 10,
      messageMaxAge = 86400,
      conversationMaxAge = 86400,
    }),
    activeConversationKey = nil,
  }

  local function refreshWindow()
    refreshCalls = refreshCalls + 1
  end

  -- Test 1: Successful character whisper sends directly
  local payload = {
    conversationKey = "me::WOW::thrall-nagrand",
    target = "Thrall-Nagrand",
    displayName = "Thrall-Nagrand",
    channel = "WOW",
    text = "hello",
  }

  local result = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(result == true, "expected send to succeed")
  assert(sentMessages[1].text == "hello")
  assert(sentMessages[1].target == "Thrall-Nagrand")

  -- Test 1b: On Classic flavors, real quest hyperlinks in the composer get
  -- serialized back to plain `[Name (id)]` before transmission. Classic's
  -- character-whisper protocol strips the `|H...|h` envelope on the wire, so
  -- the plain bracketed form is the only one that survives intact and lets
  -- the recipient's addon re-link it.
  local classicPayload = {
    conversationKey = "me::WOW::thrall-nagrand",
    target = "Thrall-Nagrand",
    displayName = "Thrall-Nagrand",
    channel = "WOW",
    text = "check |cffffff00|Hquest:471:0|h[Apprentice's Duties]|h|r",
  }
  local classicResult = SendHandler.HandleSend(runtime, classicPayload, refreshWindow)
  assert(classicResult == true, "expected classic-quest send to succeed")
  local sentClassic = sentMessages[#sentMessages].text
  local expectedClassic = "check [Apprentice's Duties (471)]"
  assert(sentClassic == expectedClassic, "expected classic quest hyperlink serialized on send, got: " .. tostring(sentClassic))
  assert(
    classicPayload.text == expectedClassic,
    "expected payload.text mutated so the bubble matches what we sent, got: " .. tostring(classicPayload.text)
  )

  -- Test 1b+: Classic sends ship a paired addon-message side channel with
  -- the id+name pairs so a recipient running the addon can splice the
  -- clickable link back in after Blizzard strips the chat text.
  do
    local addonCalls = {}
    local registeredPrefixes = {}
    runtime.chatApi.RegisterAddonMessagePrefix = function(prefix)
      table.insert(registeredPrefixes, prefix)
    end
    runtime.chatApi.SendAddonMessage = function(prefix, message, channel, target)
      table.insert(addonCalls, { prefix = prefix, message = message, channel = channel, target = target })
    end

    sentMessages = {}
    local sideChannelPayload = {
      conversationKey = "me::WOW::thrall-nagrand",
      target = "Thrall-Nagrand",
      displayName = "Thrall-Nagrand",
      channel = "WOW",
      text = "go do |cffffff00|Hquest:4641:0|h[Your Place In The World]|h|r",
    }
    SendHandler.HandleSend(runtime, sideChannelPayload, refreshWindow)

    assert(#registeredPrefixes >= 1, "expected addon prefix registered for the side channel")
    assert(registeredPrefixes[1] == "WMQL", "expected WMQL prefix")
    assert(#addonCalls == 1, "expected one paired addon-message dispatch, got: " .. tostring(#addonCalls))
    assert(addonCalls[1].prefix == "WMQL", "addon prefix forwarded")
    assert(addonCalls[1].channel == "WHISPER", "addon channel is WHISPER")
    assert(addonCalls[1].target == "Thrall-Nagrand", "addon target forwarded")
    assert(addonCalls[1].message == "4641:Your Place In The World", "encoded payload forwarded")

    -- A whisper without any quest references must NOT emit an addon message.
    addonCalls = {}
    SendHandler.HandleSend(runtime, {
      conversationKey = "me::WOW::thrall-nagrand",
      target = "Thrall-Nagrand",
      displayName = "Thrall-Nagrand",
      channel = "WOW",
      text = "just saying hi",
    }, refreshWindow)
    assert(#addonCalls == 0, "no addon message when no quest links present")

    runtime.chatApi.RegisterAddonMessagePrefix = nil
    runtime.chatApi.SendAddonMessage = nil
  end

  -- Test 1d: Classic Battle.net sends ship the same paired addon side
  -- channel via BNSendGameData so an addon-equipped BNet friend can splice
  -- the clickable link back in.
  do
    local savedBNSendWhisper = _G.BNSendWhisper
    rawset(_G, "BNSendWhisper", function()
      return true
    end)

    local gameDataCalls = {}
    local registeredPrefixes = {}
    runtime.chatApi.RegisterAddonMessagePrefix = function(prefix)
      table.insert(registeredPrefixes, prefix)
    end
    runtime.bnetApi.SendGameData = function(bnetAccountID, prefix, payload)
      table.insert(gameDataCalls, { bnetAccountID = bnetAccountID, prefix = prefix, payload = payload })
      return true
    end

    runtime.isCompetitiveContent = function()
      return false
    end
    runtime.sendStatusByConversation = {}
    runtime.pendingOutgoing = {}

    SendHandler.HandleSend(runtime, {
      conversationKey = "me::BN::jaina#1234",
      displayName = "Jaina#1234",
      battleTag = "Jaina#1234",
      channel = "BN",
      bnetAccountID = 77,
      text = "go do |cffffff00|Hquest:4641:0|h[Your Place In The World]|h|r",
    }, refreshWindow)

    assert(#gameDataCalls == 1, "expected one BNSendGameData side-channel call, got: " .. tostring(#gameDataCalls))
    assert(gameDataCalls[1].bnetAccountID == 77, "BN target forwarded")
    assert(gameDataCalls[1].prefix == "WMQL", "WMQL prefix used for BN side channel")
    assert(gameDataCalls[1].payload == "4641:Your Place In The World", "encoded quest payload forwarded, got: " .. tostring(gameDataCalls[1].payload))
    -- Prefix-registration is asserted in test 1b+ (above). AddonComm caches
    -- the registered set process-wide, so the second send won't re-call the
    -- RegisterAddonMessagePrefix stub — that's not a defect, it's the cache.

    -- A BN whisper with no quest references must NOT emit a game-data side channel.
    gameDataCalls = {}
    SendHandler.HandleSend(runtime, {
      conversationKey = "me::BN::jaina#1234",
      displayName = "Jaina#1234",
      battleTag = "Jaina#1234",
      channel = "BN",
      bnetAccountID = 77,
      text = "hi friend",
    }, refreshWindow)
    assert(#gameDataCalls == 0, "no BN side channel when no quest links present")

    runtime.chatApi.RegisterAddonMessagePrefix = nil
    runtime.bnetApi.SendGameData = nil
    rawset(_G, "BNSendWhisper", savedBNSendWhisper)
  end

  -- Test 1c: Plain `[Name (id)]` text typed manually (or inserted without our
  -- LinkHooks rewrite) passes through untouched on classic — it is already
  -- the wire form.
  local plainClassicPayload = {
    conversationKey = "me::WOW::thrall-nagrand",
    target = "Thrall-Nagrand",
    displayName = "Thrall-Nagrand",
    channel = "WOW",
    text = "[Apprentice's Duties (471)] please",
  }
  local plainResult = SendHandler.HandleSend(runtime, plainClassicPayload, refreshWindow)
  assert(plainResult == true, "expected plain-quest classic send to succeed")
  assert(
    sentMessages[#sentMessages].text == "[Apprentice's Duties (471)] please",
    "expected plain bracketed text untouched on classic, got: " .. tostring(sentMessages[#sentMessages].text)
  )

  -- Test 3: Ordinary combat still dispatches character whispers directly.
  rawset(_G, "InCombatLockdown", function()
    return true
  end)
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}
  local combatResult = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(combatResult == true, "expected character whisper to send during ordinary combat")
  assert(#sentMessages == 1, "expected direct character transport call during ordinary combat")
  assert(sentMessages[1].text == "hello", "expected direct character transport to receive text")
  assert(sentMessages[1].target == "Thrall-Nagrand", "expected direct character transport to receive target")
  assert(runtime.sendStatusByConversation[payload.conversationKey] == nil, "ordinary combat should not set a blocked send status")
  assert(refreshCalls == 1, "expected successful ordinary-combat send to refresh")

  -- Test 4: Legacy BNSendWhisper fallback supports Classic/TBC Battle.net sends

  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "BNSendWhisper", function(bnetAccountID, text)
    table.insert(sentMessages, { bnetAccountID = bnetAccountID, text = text, channel = "BN" })
    return true
  end)
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local bnPayload = {
    conversationKey = "me::BN::jaina#1234",
    displayName = "Jaina#1234",
    battleTag = "Jaina#1234",
    channel = "BN",
    bnetAccountID = 77,
    text = "hello bn",
  }

  local bnResult = SendHandler.HandleSend(runtime, bnPayload, refreshWindow)
  assert(bnResult == true, "expected Battle.net send to use legacy BNSendWhisper fallback")
  assert(#sentMessages == 1, "expected one Battle.net message to be sent")
  assert(sentMessages[1].channel == "BN", "expected Battle.net transport marker")
  assert(sentMessages[1].bnetAccountID == 77, "expected bnetAccountID to be forwarded")
  assert(sentMessages[1].text == "hello bn", "expected Battle.net text to be forwarded")

  local function makePinnedBattleNetCase(friendEntries, payloadBattleTag)
    local sentWhispers = {}
    local savedRegressionBNSendWhisper = _G.BNSendWhisper
    local conversationKey = "bnet::BN::mrgank#2355"
    rawset(_G, "BNSendWhisper", function(bnetAccountID, text)
      table.insert(sentWhispers, { bnetAccountID = bnetAccountID, text = text })
      return true
    end)

    local bnetApi = {
      GetNumFriends = function()
        return #friendEntries
      end,
      GetFriendAccountInfo = function(friendIndex)
        return friendEntries[friendIndex]
      end,
    }
    bnetApi.GetAccountInfoByID = function(bnetAccountID)
      for _, friend in ipairs(friendEntries) do
        if friend.bnetAccountID == bnetAccountID then
          return friend
        end
      end
      return nil
    end

    local regressionRuntime = {
      sendStatusByConversation = {},
      pendingOutgoing = {},
      now = function()
        return 100
      end,
      localProfileId = "me",
      chatApi = {},
      bnetApi = bnetApi,
      store = Store.New({
        maxMessagesPerConversation = 20,
        maxConversations = 10,
        messageMaxAge = 86400,
        conversationMaxAge = 86400,
      }),
      activeConversationKey = conversationKey,
    }
    regressionRuntime.store.conversations[conversationKey] = {
      conversationKey = conversationKey,
      channel = "BN",
      displayName = "MrGank#2355",
      battleTag = "MrGank#2355",
      bnetAccountID = 12,
      pinned = true,
      messages = {},
    }

    local battleTag = payloadBattleTag or "MrGank#2355"
    return regressionRuntime,
      {
        conversationKey = conversationKey,
        displayName = battleTag,
        battleTag = battleTag,
        channel = "BN",
        bnetAccountID = 12,
        text = "hello MrGank",
      },
      sentWhispers,
      function()
        rawset(_G, "BNSendWhisper", savedRegressionBNSendWhisper)
      end
  end

  local recycledIdFriends = {
    { bnetAccountID = 12, battleTag = "Bananasaur#2885", isOnline = true },
    { bnetAccountID = 13, battleTag = "MrGank#2355", isOnline = true },
  }

  -- Regression: a pinned BattleTag must resolve past recycled account ID 12.
  do
    local regressionRuntime, pinnedPayload, sentWhispers, restore = makePinnedBattleNetCase(recycledIdFriends)
    local conversationKey = pinnedPayload.conversationKey
    local resolvedResult = SendHandler.HandleSend(regressionRuntime, pinnedPayload, function() end)
    assert(resolvedResult == true, "expected pinned MrGank Battle.net send to succeed")
    assert(#sentWhispers == 1, "expected one Battle.net whisper, got: " .. tostring(#sentWhispers))
    assert(
      sentWhispers[1].bnetAccountID == 13,
      "expected live MrGank ID13 instead of stale Bananasaur ID12, got: " .. tostring(sentWhispers[1].bnetAccountID)
    )
    assert(sentWhispers[1].bnetAccountID ~= 12, "must never dispatch stale Bananasaur ID12")
    assert(pinnedPayload.bnetAccountID == 13, "expected resolved payload to refresh from stale Bananasaur ID12 to live MrGank ID13")
    assert(
      regressionRuntime.store.conversations[conversationKey].bnetAccountID == 13,
      "expected pinned conversation to refresh from stale Bananasaur ID12 to live MrGank ID13"
    )
    local pending = regressionRuntime.pendingOutgoing[conversationKey]
    assert(pending and #pending == 1, "expected one pending send for stable MrGank conversation")
    assert(pending[1].bnetAccountID == 13, "expected pending send to target recovered MrGank ID13")
    assert(regressionRuntime.pendingOutgoing["bnet::BN::bananasaur#2885"] == nil, "must not create a stale Bananasaur ID12 pending queue")

    restore()
  end

  -- Regression: an unresolved pinned BattleTag must not fall back to recycled ID 12.
  do
    local regressionRuntime, unresolvedPayload, sentWhispers, restore = makePinnedBattleNetCase({ recycledIdFriends[1] })
    local unresolvedResult = SendHandler.HandleSend(regressionRuntime, unresolvedPayload, function() end)
    assert(unresolvedResult == false, "expected unresolved MrGank#2355 send to fail; stale Bananasaur#2885 ID12 must never receive it")
    assert(
      #sentWhispers == 0,
      "expected no whisper when MrGank#2355 cannot resolve; stale Bananasaur#2885 ID12 received: " .. tostring(#sentWhispers)
    )
    assert(next(regressionRuntime.pendingOutgoing) == nil, "unresolved recipient must not create a pending send")
    local sendStatus = regressionRuntime.sendStatusByConversation[unresolvedPayload.conversationKey]
    assert(sendStatus ~= nil, "expected unavailable send status for unresolved recipient")
    assert(sendStatus.status == "Send unavailable", "expected Send unavailable status, got: " .. tostring(sendStatus.status))

    restore()
  end

  -- Regression: a conflicting payload BattleTag must not replace a pinned identity.
  do
    local regressionRuntime, conflictPayload, sentWhispers, restore = makePinnedBattleNetCase(recycledIdFriends, "Bananasaur#2885")
    local conversation = regressionRuntime.store.conversations[conflictPayload.conversationKey]
    conversation.bnetAccountID = 13
    conflictPayload.text = "look at [Apprentice's Duties (471)]"
    local originalConflictText = conflictPayload.text

    local conflictResult = SendHandler.HandleSend(regressionRuntime, conflictPayload, function() end)
    assert(conflictResult == false, "expected payload BattleTag conflict with pinned MrGank identity to fail closed")
    assert(conflictPayload.text == originalConflictText, "conflicting payload quest text must not be rewritten before rejection")
    assert(#sentWhispers == 0, "conflicting payload must not dispatch a Battle.net whisper")
    assert(next(regressionRuntime.pendingOutgoing) == nil, "conflicting payload must not create a pending send")
    assert(conversation.displayName == "MrGank#2355", "pinned display name must not be replaced by payload identity")
    assert(conversation.battleTag == "MrGank#2355", "pinned BattleTag must not be replaced by payload identity")
    assert(conversation.bnetAccountID == 13, "pinned MrGank account ID must not be replaced by payload ID12")

    restore()
  end

  -- Test 5: Competitive content blocks character whisper sends

  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  runtime.isCompetitiveContent = function()
    return true
  end
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local competitiveResult = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(competitiveResult == false, "expected send to be blocked during competitive content")
  assert(#sentMessages == 0, "should not send during competitive content")
  assert(refreshCalls == 1, "should refresh to show competitive status")

  local competitiveStatus = runtime.sendStatusByConversation[payload.conversationKey]
  assert(competitiveStatus ~= nil, "expected competitive status to be set")
  assert(competitiveStatus.status == "Competitive Content", "expected 'Competitive Content' status, got: " .. tostring(competitiveStatus.status))

  -- Blocked outgoing message should be recorded
  local compConversation = runtime.store.conversations[payload.conversationKey]
  assert(compConversation ~= nil, "expected conversation to exist after competitive block")
  local lastMsg = compConversation.messages[#compConversation.messages]
  assert(lastMsg.delivery == "blocked", "expected blocked delivery marker")
  assert(lastMsg.blockedReason == "Competitive Content", "expected competitive blocked reason")

  -- Test 6: Competitive content does NOT block when isCompetitiveContent returns false
  runtime.isCompetitiveContent = function()
    return false
  end
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local notCompResult = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(notCompResult == true, "expected send to succeed when not in competitive content")
  assert(#sentMessages == 1, "should send when not in competitive content")

  runtime.isCompetitiveContent = nil

  -- Battle.net channel still routes through SendHandler when nothing blocks.
  local traceLines = {}
  local savedPrint = _G.print

  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}
  rawset(_G, "BNSendWhisper", function(bnetAccountID, text)
    table.insert(sentMessages, { bnetAccountID = bnetAccountID, text = text, channel = "BN" })
    return true
  end)
  rawset(_G, "print", function(_, line)
    table.insert(traceLines, line)
  end)
  Trace.enable()

  local bnPayload2 = {
    conversationKey = "me::BN::thrall#1234",
    displayName = "Thrall-Nagrand",
    battleTag = "Thrall#1234",
    channel = "BN",
    bnetAccountID = 99,
    text = "bn hello",
  }
  local bnResult2 = SendHandler.HandleSend(runtime, bnPayload2, refreshWindow)
  assert(bnResult2 == true, "expected BN send to go through")
  assert(#sentMessages == 1, "expected BN send to reach the gateway")

  rawset(_G, "InCombatLockdown", function()
    return true
  end)
  local combatTraceResult = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(combatTraceResult == true, "expected ordinary-combat send to return true with tracing enabled")
  Trace.disable()
  rawset(_G, "print", savedPrint)
  assert(traceLines[1] == "SendHandler: entry channel=BN inCombat=false")
  assert(traceLines[2] == "SendHandler: bnet-resolve outcome=matched")
  assert(traceLines[3] == "SendHandler: dispatch transport=BN")
  assert(traceLines[4] == "SendHandler: bnet-pcall ok=true")
  assert(traceLines[5] == "SendHandler: return result=true")
  assert(traceLines[6] == "SendHandler: entry channel=WOW inCombat=true")
  assert(traceLines[7] == "SendHandler: dispatch transport=WOW")
  assert(traceLines[8] == "SendHandler: return result=true")
  local traceOutput = table.concat(traceLines, "\n")
  for _, sensitiveValue in ipairs({
    "me::BN::thrall#1234",
    "Thrall#1234",
    "Thrall-Nagrand",
    "oldID",
    "resolvedID",
    "99",
    "bn hello",
  }) do
    assert(not string.find(traceOutput, sensitiveValue, 1, true), "trace must not identify recipient: " .. sensitiveValue)
  end

  rawset(_G, "InCombatLockdown", savedInCombatLockdown)
  rawset(_G, "BNSendWhisper", savedBNSendWhisper)
end
