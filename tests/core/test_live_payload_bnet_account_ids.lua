local BNetResolver = require("WhisperMessenger.Transport.BNetResolver")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local LivePayload = require("WhisperMessenger.Core.Bootstrap.EventBridge.LivePayload")
local Store = require("WhisperMessenger.Model.ConversationStore")

local BNET_WHISPER_EVENTS = {
  "CHAT_MSG_BN_WHISPER",
  "CHAT_MSG_BN_WHISPER_INFORM",
  "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE",
}

local function bnetWhisperArgs()
  return "message", "Friend", nil, nil, nil, nil, nil, nil, nil, nil, 1, "Player-1-ABCDE", 42
end

local function newRuntime(bnetApi)
  return {
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    localProfileId = "me",
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
    bnetApi = bnetApi,
  }
end

return function()
  -- Secret IDs must be removed before resolver and router boundaries.
  do
    local secretID = 42
    local apiCalls = 0
    local resolveCalls = 0
    local originalIsSecretValue = _G.issecretvalue
    local originalResolve = BNetResolver.ResolveAccountInfo
    local runtime = newRuntime({
      GetGameAccountInfoByID = function()
        apiCalls = apiCalls + 1
      end,
      GetAccountInfoByID = function()
        apiCalls = apiCalls + 1
      end,
    })
    local whisperPayloads = {}
    local routeSucceeded = {}
    _G.issecretvalue = function(value)
      return value == secretID
    end
    BNetResolver.ResolveAccountInfo = function(...)
      resolveCalls = resolveCalls + 1
      return originalResolve(...)
    end

    local addonPayload = LivePayload.Build(runtime, "BN_CHAT_MSG_ADDON", "WMRX", "payload", "WHISPER", secretID)

    for _, eventName in ipairs(BNET_WHISPER_EVENTS) do
      whisperPayloads[eventName] = LivePayload.Build(runtime, eventName, bnetWhisperArgs())
      routeSucceeded[eventName] = pcall(EventBridge.RouteLiveEvent, runtime, nil, eventName, bnetWhisperArgs())
    end

    BNetResolver.ResolveAccountInfo = originalResolve
    _G.issecretvalue = originalIsSecretValue

    assert(addonPayload.gameAccountID == nil, "BN addon secret gameAccountID should be removed")
    assert(addonPayload.bnetAccountID == nil, "BN addon secret gameAccountID should not resolve an account")
    for _, eventName in ipairs(BNET_WHISPER_EVENTS) do
      assert(whisperPayloads[eventName].bnetAccountID == nil, eventName .. " secret ID should be removed")
      assert(routeSucceeded[eventName], eventName .. " with secret ID should route without error")
    end
    assert(resolveCalls == 0, "secret IDs should not reach ResolveAccountInfo")
    assert(apiCalls == 0, "secret IDs should not call BNet APIs")
  end

  -- BN addon sender is a gameAccountID and resolves to the owning BNet account.
  do
    local accountInfo = {
      bnetAccountID = 42,
      battleTag = "Friend#1234",
      isOnline = true,
      gameAccountInfo = {
        gameAccountID = 4200,
        playerGuid = "Player-1-ABCDE",
      },
    }
    local runtime = newRuntime({
      GetGameAccountInfoByID = function(id)
        assert(id == 4200, "BN addon sender should reach game-account lookup unchanged")
        return accountInfo.gameAccountInfo
      end,
      GetAccountInfoByGUID = function(guid)
        assert(guid == "Player-1-ABCDE", "game-account player GUID should resolve BNet account")
        return accountInfo
      end,
      GetAccountInfoByID = function(id)
        assert(id == 42, "normal BN whisper should keep bnetAccountID lookup")
        return accountInfo
      end,
    })
    local addonPayload = LivePayload.Build(runtime, "BN_CHAT_MSG_ADDON", "WMRX", "payload", "WHISPER", 4200)
    assert(addonPayload.gameAccountID == 4200, "BN addon payload should preserve safe gameAccountID")
    assert(addonPayload.bnetAccountID == 42, "BN addon gameAccountID should resolve to bnetAccountID")
    assert(addonPayload.accountInfo == accountInfo, "BN addon payload should carry resolved account context")

    for _, eventName in ipairs(BNET_WHISPER_EVENTS) do
      local payload = LivePayload.Build(runtime, eventName, bnetWhisperArgs())
      assert(payload.bnetAccountID == 42, eventName .. " should keep normal bnetAccountID")
    end
  end
end
