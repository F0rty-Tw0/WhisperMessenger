local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Availability = require("WhisperMessenger.Transport.Availability")
local Store = require("WhisperMessenger.Model.ConversationStore")

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
    bnetApi = {},
    isChatMessagingLocked = function()
      return false
    end,
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
    rawset(_G, "BNSendWhisper", function() return true end)

    local gameDataCalls = {}
    local registeredPrefixes = {}
    runtime.chatApi.RegisterAddonMessagePrefix = function(prefix)
      table.insert(registeredPrefixes, prefix)
    end
    runtime.bnetApi.SendGameData = function(bnetAccountID, prefix, payload)
      table.insert(gameDataCalls, { bnetAccountID = bnetAccountID, prefix = prefix, payload = payload })
      return true
    end

    rawset(runtime, "isChatMessagingLocked", function() return false end)
    runtime.isCompetitiveContent = function() return false end
    runtime.sendStatusByConversation = {}
    runtime.pendingOutgoing = {}

    SendHandler.HandleSend(runtime, {
      conversationKey = "me::BN::jaina#1234",
      displayName = "Jaina#1234",
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

  -- Test 2: Combat lockdown blocks character whisper sends
  rawset(runtime, "isChatMessagingLocked", function()
    return true
  end)
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local lockedResult = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(lockedResult == false, "expected send to be blocked during lockdown")
  assert(#sentMessages == 0, "should not send during lockdown")
  assert(refreshCalls == 1, "should refresh to show lockdown status")

  local status = runtime.sendStatusByConversation[payload.conversationKey]
  assert(status ~= nil, "expected lockdown status to be set")
  assert(status.status == "Lockdown", "expected Lockdown status, got: " .. tostring(status.status))
  local blockedConversation = runtime.store.conversations[payload.conversationKey]
  assert(blockedConversation ~= nil, "expected blocked send to be recorded in conversation")
  assert(#blockedConversation.messages == 1, "expected one blocked outgoing message")
  assert(blockedConversation.messages[1].delivery == "blocked", "expected blocked outgoing delivery marker")
  assert(blockedConversation.messages[1].text == "hello", "expected blocked outgoing text to be preserved")

  -- Test 3: Global InCombatLockdown blocks character whisper sends
  rawset(runtime, "isChatMessagingLocked", function()
    return false
  end)
  rawset(_G, "InCombatLockdown", function()
    return true
  end)
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local combatResult = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(combatResult == false, "expected send to be blocked when InCombatLockdown is true")
  assert(#sentMessages == 0, "should not send while InCombatLockdown is true")
  assert(refreshCalls == 1, "should refresh to show lockdown status when InCombatLockdown is true")

  local combatStatus = runtime.sendStatusByConversation[payload.conversationKey]
  assert(combatStatus ~= nil, "expected lockdown status while InCombatLockdown is true")
  assert(combatStatus.status == "Lockdown", "expected Lockdown status during InCombatLockdown")
  local combatConversation = runtime.store.conversations[payload.conversationKey]
  assert(combatConversation ~= nil, "expected conversation to exist after InCombatLockdown block")
  assert(#combatConversation.messages == 2, "expected second blocked outgoing message to be recorded")
  assert(combatConversation.messages[2].blockedReason == "Lockdown", "expected blocked reason Lockdown on InCombatLockdown block")

  -- Test 4: Legacy BNSendWhisper fallback supports Classic/TBC Battle.net sends
  rawset(runtime, "isChatMessagingLocked", function()
    return false
  end)
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

  -- Test 5: Competitive content blocks character whisper sends
  rawset(runtime, "isChatMessagingLocked", function()
    return false
  end)
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
  rawset(runtime, "isChatMessagingLocked", function()
    return false
  end)
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

  local bnPayload2 = {
    conversationKey = "me::BN::thrall#1234",
    displayName = "Thrall-Nagrand",
    channel = "BN",
    bnetAccountID = 99,
    text = "bn hello",
  }
  local bnResult2 = SendHandler.HandleSend(runtime, bnPayload2, refreshWindow)
  assert(bnResult2 == true, "expected BN send to go through")
  assert(#sentMessages == 1, "expected BN send to reach the gateway")

  rawset(_G, "InCombatLockdown", savedInCombatLockdown)
  rawset(_G, "BNSendWhisper", savedBNSendWhisper)
end
