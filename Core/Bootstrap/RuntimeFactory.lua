local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local ChannelMessageStore = ns.ChannelMessageStore or require("WhisperMessenger.Model.ChannelMessageStore")
local ContentDetector = ns.ContentDetector or require("WhisperMessenger.Core.ContentDetector")
local BNetIdentity = ns.BNetIdentity or require("WhisperMessenger.Core.BNetIdentity")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local OutgoingDelivery = ns.OutgoingDelivery or require("WhisperMessenger.Model.OutgoingDelivery")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local RulePresets = ns.RulePresets or require("WhisperMessenger.Model.Filters.RulePresets")
local ContactInfo = ns.ContactInfo or require("WhisperMessenger.Model.ContactInfo")
local PanelRegistry = ns.BootstrapWindowRuntimePanelRegistry or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelRegistry")
local OptionalFields = ns.BootstrapRuntimeFactoryOptionalFields or require("WhisperMessenger.Core.Bootstrap.RuntimeFactory.OptionalFields")
local RuntimeFactory = {}

-- Session maps keyed by conversation, declared in CreateRuntimeState and
-- cleared here when a chat is removed: the alert throttle, "notify when
-- online" state and the contacts known to run the addon.
local SESSION_MAPS_BY_CONVERSATION = { "lastAlertAtByConversation", "onlineWatch", "livePresencePeers" }

-- Every runtime field has a default in CreateRuntimeState or is named in
-- OPTIONAL_FIELDS; tests/core/test_runtime_shape.lua fails on any other.
RuntimeFactory.OPTIONAL_FIELDS = OptionalFields

local function noop() end

local function returnFalse()
  return false
end

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

local function conversationOwnsGUID(store, guid)
  for _, conversation in pairs(store.conversations) do
    if conversation.guid == guid then
      return true
    end
  end
  return false
end

-- A panel whose addon lost its integration permission is inactive. Read at
-- call time: PublicApi.Publish sets the integration registry later.
local function isPanelActive(runtime, key)
  local registry = runtime.addonIntegrations
  if registry == nil then
    return true
  end
  local owner = registry.ownerOf("panel", key)
  return owner == nil or registry.isAllowed(owner)
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
  }, nowFn)

  store.conversations = accountState.conversations or {}
  accountState.conversations = store.conversations

  Store.ExpireAll(store, nowValue)

  local channelMessageStore = ChannelMessageStore.Restore(accountState.channelMessages, nil, nowValue)
  accountState.channelMessages = channelMessageStore

  -- Ignore entries expire lazily; this login sweep drops the ones that ran
  -- out while the player was offline.
  local filters = IgnoreList.Ensure(accountState)
  IgnoreList.Sweep(filters, nowValue)
  IgnoreList.ClearBlockedCounts(filters)
  RulePresets.Seed(filters)

  -- Channels the player turned into chats; none until picked in Options.
  accountState.settings = accountState.settings or {}
  accountState.settings.enabledChannels = accountState.settings.enabledChannels or {}

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

  -- Party GUIDs persist per character: /reload does not re-fire GROUP_JOINED,
  -- so without them group chat would fork into a new thread after reload.
  characterState.groupPartyGUIDs = characterState.groupPartyGUIDs or {}

  local getBNetInfo = options.getBNetInfo or _G.BNGetInfo
  local localBnetAccountID = BNetIdentity.ResolveLocalAccountID(options.localBnetAccountID, getBNetInfo)

  OutgoingDelivery.SetLocalProfileId(localProfileId)

  local runtime
  runtime = {
    -- Identity
    accountState = accountState,
    characterState = characterState,
    localProfileId = localProfileId,
    localPlayerGuid = localPlayerGuid,
    localBnetAccountID = localBnetAccountID,
    getBNetInfo = getBNetInfo,
    localFaction = options.localFaction or (type(_G["UnitFactionGroup"]) == "function" and _G["UnitFactionGroup"]("player") or nil),
    now = nowFn,

    -- Game APIs
    chatApi = options.chatApi or _G.C_ChatInfo or {},
    bnetApi = options.bnetApi or _G.C_BattleNet or {},
    friendListApi = options.friendListApi or _G.C_FriendList or {},
    playerInfoByGUID = options.playerInfoByGUID or _G.GetPlayerInfoByGUID,

    -- Stores
    store = store,
    channelMessageStore = channelMessageStore,
    activeConversationKey = characterState.activeConversationKey,
    groupPartyGUIDsByCategory = characterState.groupPartyGUIDs,
    contactInfo = ContactInfo.New(),
    panelRegistry = PanelRegistry.New({
      isActive = function(key)
        return isPanelActive(runtime, key)
      end,
    }),

    -- Session caches: gone on reload.
    pendingOutgoing = {},
    pendingGroupOutgoing = {},
    sendStatusByConversation = {},
    availabilityByGUID = {},
    availabilityRequestedAt = {},
    -- Duplicate-collapse index: rebuilt lazily per chat.
    collapseIndex = {},
    typingByConversation = {},
    typingExpiryPending = {},
    typingOut = {},
    livePresencePeers = {},
    lastAlertAtByConversation = {},
    onlineWatch = {},
    relationshipCache = {},
    questLinkInbox = {},
    questLinkCleanupScheduled = false,
    replyLinksStaged = {},
    addonGreetingInbox = {},
    addonGreetingLate = {},
    messageReactionWireSequence = 0,
    queuedSendsLocked = false,
    zoneRosterPollPending = false,

    -- Restriction predicates. Bootstrap.Initialize points them at the
    -- restriction instance once the window runtime is built.
    isMythicLockdown = options.isMythicLockdown or function()
      return ContentDetector.IsMythicRestricted(_G.GetInstanceInfo)
    end,
    isCompetitiveContent = returnFalse,
    isChannelIngestSuspended = returnFalse,

    -- Window controller: does nothing until WindowRuntime binds it.
    toggle = noop,
    toggleTargetKey = noop,
    setWindowVisible = noop,
    refreshWindow = noop,
    scheduleIncomingRefresh = noop,
    updateIconSurfaces = noop,
    setComposerText = noop,
    startConversation = returnFalse,
    canReact = returnFalse,
    getWidgetIcon = noop,
    getGroupSendNotice = noop,

    -- Callbacks other modules replace with their own.
    syncChatFilters = noop,
    syncReplyKey = noop,
    suspend = noop,
    resume = noop,
    onAvailabilityChanged = noop,
    onAutoOpen = noop,
    onAutoOpenOutgoing = noop,
    ---@type fun(conversationKey: string)
    onConversationRemoved = noop,
    onReactionFallbackDegraded = noop,
    onGroupReactionFallbackDegraded = noop,
  }

  local function clearGUIDCachesIfUnowned(guid)
    if guid == nil or conversationOwnsGUID(store, guid) then
      return
    end
    runtime.availabilityByGUID[guid] = nil
    if runtime.availabilityRequestedAt then
      runtime.availabilityRequestedAt[guid] = nil
    end
  end

  store.onConversationRemoved = function(key, conversation, reason)
    if reason == "explicit" then
      MessageReactions.ClearConversation(runtime, key)
    end
    runtime.sendStatusByConversation[key] = nil
    runtime.collapseIndex[key] = nil
    for _, field in ipairs(SESSION_MAPS_BY_CONVERSATION) do
      local map = runtime[field]
      if map then
        map[key] = nil
      end
    end

    clearGUIDCachesIfUnowned(conversation.guid)

    if runtime.activeConversationKey == key then
      runtime.activeConversationKey = nil
      characterState.activeConversationKey = nil
    end
    -- Reply-to-last must not target a conversation that is gone.
    if runtime.lastIncomingWhisperKey == key then
      runtime.lastIncomingWhisperKey = nil
    end
    -- Session UI state for the key (a pending reply) goes with it.
    if type(runtime.onConversationRemoved) == "function" then
      runtime.onConversationRemoved(key)
    end
  end
  store.onConversationGUIDChanged = function(_key, oldGuid)
    clearGUIDCachesIfUnowned(oldGuid)
  end

  return runtime
end

ns.BootstrapRuntimeFactory = RuntimeFactory
return RuntimeFactory
