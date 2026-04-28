local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local ChannelMessageStore = ns.ChannelMessageStore or require("WhisperMessenger.Model.ChannelMessageStore")
local Queue = ns.LockdownQueue or require("WhisperMessenger.Model.LockdownQueue")
local ContentDetector = ns.ContentDetector or require("WhisperMessenger.Core.ContentDetector")
local RuntimeFactory = {}

local function currentTime()
  if type(_G["time"]) == "function" then
    return _G["time"]()
  end
  return 0
end

function RuntimeFactory.ResolveLocalProfileId(options)
  if options.localProfileId ~= nil then
    return options.localProfileId
  end

  local unitFullName = options.unitFullName or _G["UnitFullName"]
  local unitName = options.unitName or _G["UnitName"]
  local getNormalizedRealmName = options.getNormalizedRealmName or _G["GetNormalizedRealmName"]
  local getRealmName = options.getRealmName or _G["GetRealmName"]

  local name
  local realmName

  if type(unitFullName) == "function" then
    name, realmName = unitFullName("player")
  elseif type(unitName) == "function" then
    name, realmName = unitName("player")
  end

  if realmName == nil or realmName == "" then
    if type(getNormalizedRealmName) == "function" then
      realmName = getNormalizedRealmName()
    elseif type(getRealmName) == "function" then
      realmName = getRealmName()
    end
  end

  local profileId = Identity.BuildLocalProfileId(name, realmName)
  if profileId ~= nil then
    return profileId
  end

  -- Safe fallback for stripped test environments where player identity APIs are unavailable.
  return "current"
end

function RuntimeFactory.CreateRuntimeState(accountState, characterState, localProfileId, options)
  local nowFn = options.now or currentTime
  local nowValue = nowFn()
  local saved = accountState.settings or {}
  local messageMaxAge = options.messageMaxAge or saved.messageMaxAge or 86400
  local store = Store.New({
    maxMessagesPerConversation = options.maxMessagesPerConversation or saved.maxMessagesPerConversation or 200,
    maxConversations = options.maxConversations or saved.maxConversations or 100,
    messageMaxAge = messageMaxAge,
    conversationMaxAge = options.conversationMaxAge or messageMaxAge,
  })

  store.conversations = accountState.conversations or {}
  accountState.conversations = store.conversations

  Store.ExpireAll(store, nowValue)

  local channelMessageStore = ChannelMessageStore.Restore(accountState.channelMessages, nil, nowValue)
  accountState.channelMessages = channelMessageStore

  -- Resolve local player identity for group-chat direction detection.
  -- UnitGUID("player") returns nil during very early load or in minimal test
  -- environments; pcall-guard and let it stay nil — direction falls back to
  -- "in" for all messages, which matches pre-group-chat behavior.
  local localPlayerGuid = options.localPlayerGuid
  if localPlayerGuid == nil and type(_G.UnitGUID) == "function" then
    local ok, guid = pcall(_G.UnitGUID, "player")
    if ok and type(guid) == "string" and guid ~= "" then
      localPlayerGuid = guid
    end
  end

  return {
    accountState = accountState,
    characterState = characterState,
    localProfileId = localProfileId,
    localPlayerGuid = localPlayerGuid,
    localBnetAccountID = options.localBnetAccountID,
    activeConversationKey = characterState.activeConversationKey,
    pendingOutgoing = {},
    sendStatusByConversation = {},
    availabilityByGUID = {},
    chatApi = options.chatApi or _G.C_ChatInfo or {},
    bnetApi = options.bnetApi or _G.C_BattleNet or {},
    friendListApi = options.friendListApi or _G.C_FriendList or {},
    playerInfoByGUID = options.playerInfoByGUID or _G.GetPlayerInfoByGUID,
    localFaction = options.localFaction or (type(_G["UnitFactionGroup"]) == "function" and _G["UnitFactionGroup"]("player") or nil),
    store = store,
    channelMessageStore = channelMessageStore,
    queue = Queue.New(),
    now = nowFn,
    isChatMessagingLocked = options.isChatMessagingLocked or function()
      return false
    end,
    isMythicLockdown = options.isMythicLockdown or function()
      return ContentDetector.IsMythicRestricted(_G.GetInstanceInfo)
    end,
  }
end

ns.BootstrapRuntimeFactory = RuntimeFactory
return RuntimeFactory
