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

  return {
    accountState = accountState,
    characterState = characterState,
    localProfileId = localProfileId,
    activeConversationKey = characterState.activeConversationKey,
    pendingOutgoing = {},
    sendStatusByConversation = {},
    availabilityByGUID = {},
    chatApi = options.chatApi or _G.C_ChatInfo or {},
    bnetApi = options.bnetApi or _G.C_BattleNet or {},
    playerInfoByGUID = options.playerInfoByGUID or _G.GetPlayerInfoByGUID,
    localFaction = options.localFaction
      or (type(_G["UnitFactionGroup"]) == "function" and _G["UnitFactionGroup"]("player") or nil),
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
