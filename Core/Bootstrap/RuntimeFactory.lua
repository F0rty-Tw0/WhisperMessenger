local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local Loader = ns.Loader or (type(require) == "function" and (function()
  local ok, L = pcall(require, "WhisperMessenger.Core.Loader")
  return ok and L or nil
end)())
local loadModule = Loader and Loader.LoadModule or function(name, key)
  if ns[key] then return ns[key] end
  if type(require) == "function" then
    local ok, loaded = pcall(require, name)
    if ok then return loaded end
  end
  error(key .. " module not available")
end

local RuntimeFactory = {}

local function currentTime()
  if type(_G.time) == "function" then return _G.time() end
  return 0
end

function RuntimeFactory.ResolveLocalProfileId(options)
  if options.localProfileId ~= nil then
    return options.localProfileId
  end

  local Identity = loadModule("WhisperMessenger.Model.Identity", "Identity")
  local unitFullName = options.unitFullName or _G.UnitFullName
  local unitName = options.unitName or _G.UnitName
  local getNormalizedRealmName = options.getNormalizedRealmName or _G.GetNormalizedRealmName
  local getRealmName = options.getRealmName or _G.GetRealmName

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
  local Store = loadModule("WhisperMessenger.Model.ConversationStore", "ConversationStore")
  local Queue = loadModule("WhisperMessenger.Model.LockdownQueue", "LockdownQueue")
  local store = Store.New({
    maxMessagesPerConversation = options.maxMessagesPerConversation,
  })

  store.conversations = accountState.conversations or {}
  accountState.conversations = store.conversations

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
    store = store,
    queue = Queue.New(),
    now = options.now or currentTime,
    isChatMessagingLocked = options.isChatMessagingLocked or function()
      return false
    end,
  }
end

ns.BootstrapRuntimeFactory = RuntimeFactory
return RuntimeFactory
