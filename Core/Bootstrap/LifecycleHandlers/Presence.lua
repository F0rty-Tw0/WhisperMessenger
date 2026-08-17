local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon
  or (type(require) == "function" and require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common"))
  or nil
local ConversationMerge = ns.ConversationMerge or require("WhisperMessenger.Model.ConversationMerge")

local Presence = {}

function Presence.handlePlayerLogout(Bootstrap, deps)
  if Bootstrap.runtime then
    local runtime = Bootstrap.runtime
    local settings = runtime.accountState and runtime.accountState.settings
    if settings and settings.clearOnLogout then
      for key in pairs(runtime.store.conversations) do
        runtime.store.conversations[key] = nil
      end
      runtime.activeConversationKey = nil
      if runtime.characterState then
        runtime.characterState.activeConversationKey = nil
      end
      runtime.lastIncomingWhisperKey = nil
      deps.trace("clear on logout")
    end
  end

  return true
end

-- BN whispers that arrived before the friend list resolved are keyed by the
-- session-scoped numeric account ID (no battleTag was available). Once the
-- friend list is readable, fold those orphans into the stable battleTag
-- conversation so history isn't split — and isn't stranded next session
-- when the numeric ID changes.
local function rekeyOrphanedBNetConversations(conversations, friendMap, Identity, maxMessages)
  local tagById = {}
  for battleTag, friend in pairs(friendMap) do
    if friend.bnetAccountID ~= nil then
      tagById[friend.bnetAccountID] = battleTag
    end
  end

  local moves = {}
  for key, conversation in pairs(conversations) do
    if conversation.channel == "BN" and conversation.battleTag == nil then
      local battleTag = conversation.bnetAccountID and tagById[conversation.bnetAccountID]
      if battleTag then
        local contact = Identity.FromBattleNet(conversation.bnetAccountID, { battleTag = battleTag })
        local newKey = Identity.BuildConversationKey(nil, contact.contactKey)
        if newKey ~= key then
          moves[key] = { newKey = newKey, battleTag = battleTag }
        end
      end
    end
  end

  local mappings = {}
  for oldKey, move in pairs(moves) do
    local conversation = conversations[oldKey]
    if conversation then
      conversation.battleTag = move.battleTag
      if conversation.displayName == nil or conversation.displayName == tostring(conversation.bnetAccountID) then
        conversation.displayName = move.battleTag
      end
      local rekeyed = ConversationMerge.Rekey(conversations, oldKey, move.newKey, maxMessages)
      for sourceKey, destinationKey in pairs(rekeyed) do
        mappings[sourceKey] = destinationKey
      end
    end
  end

  return mappings
end

local function applyRekeyMappings(runtime, mappings)
  if runtime.activeConversationKey ~= nil then
    runtime.activeConversationKey = mappings[runtime.activeConversationKey] or runtime.activeConversationKey
  end
  if runtime.characterState and runtime.characterState.activeConversationKey ~= nil then
    runtime.characterState.activeConversationKey = mappings[runtime.characterState.activeConversationKey]
      or runtime.characterState.activeConversationKey
  end
  if runtime.lastIncomingWhisperKey ~= nil then
    runtime.lastIncomingWhisperKey = mappings[runtime.lastIncomingWhisperKey] or runtime.lastIncomingWhisperKey
  end
end

local function refreshBNetConversations(Bootstrap, deps)
  if Bootstrap.runtime == nil then
    return
  end

  local BNetResolver = deps.loadModule("WhisperMessenger.Transport.BNetResolver", "BNetResolver")
  local friendMap = BNetResolver.ScanFriendList(Bootstrap.runtime.bnetApi)

  local Identity = deps.loadModule("WhisperMessenger.Model.Identity", "Identity")
  local maxMessages = Bootstrap.runtime.store.config and Bootstrap.runtime.store.config.maxMessagesPerConversation
  local mappings = rekeyOrphanedBNetConversations(Bootstrap.runtime.store.conversations, friendMap, Identity, maxMessages)
  applyRekeyMappings(Bootstrap.runtime, mappings)

  for _, conversation in pairs(Bootstrap.runtime.store.conversations) do
    if conversation.channel == "BN" and conversation.battleTag then
      local friend = friendMap[conversation.battleTag]
      if friend then
        conversation.bnetAccountID = friend.bnetAccountID
        local gameInfo = friend.accountInfo and friend.accountInfo.gameAccountInfo
        if gameInfo then
          if gameInfo.factionName and gameInfo.factionName ~= "" then
            conversation.factionName = gameInfo.factionName
          end
          if gameInfo.className and gameInfo.className ~= "" then
            conversation.className = gameInfo.className
          end
          if gameInfo.raceName and gameInfo.raceName ~= "" then
            conversation.raceName = gameInfo.raceName
          end
          if gameInfo.characterName and gameInfo.characterName ~= "" then
            local realmSuffix = (gameInfo.realmName and gameInfo.realmName ~= "") and ("-" .. gameInfo.realmName) or ""
            conversation.gameAccountName = gameInfo.characterName .. realmSuffix
          end
        end
      end
    end
  end

  Common.refreshRuntimeWindow(Bootstrap)
end

function Presence.handleBNetFriendEvent(Bootstrap, deps)
  if Bootstrap.runtime == nil then
    return true
  end

  -- BN_FRIEND_INFO_CHANGED fires in bursts (one per presence change, often
  -- several per second with a large friend list), and each scan walks every
  -- friend and every conversation. Debounce into one deferred scan, same as
  -- handlePresenceInvalidation; run synchronously when timers are
  -- unavailable so nothing is dropped.
  if Bootstrap._bnetFriendRefreshPending then
    return true
  end
  Bootstrap._bnetFriendRefreshPending = true
  local scheduled = Common ~= nil
    and Common.scheduleAfter(2, function()
      Bootstrap._bnetFriendRefreshPending = false
      refreshBNetConversations(Bootstrap, deps)
    end)
  if not scheduled then
    Bootstrap._bnetFriendRefreshPending = false
    refreshBNetConversations(Bootstrap, deps)
  end
  return true
end

local function schedulePresenceRefresh(Bootstrap, PresenceCache, deps)
  if Common == nil then
    return
  end
  Common.scheduleAfter(2, function()
    if Bootstrap._inMythicContent then
      return
    end
    deps.trace("PresenceCache: initial rebuild (PLAYER_ENTERING_WORLD +2s)")
    PresenceCache.Rebuild()
    Common.refreshRuntimeWindow(Bootstrap)
  end)

  if Bootstrap._presenceTimerLoopStarted then
    return
  end

  local function presenceTimerLoop()
    if not Bootstrap._inMythicContent and PresenceCache.IsStale() then
      deps.trace("PresenceCache: timer rebuild (TTL=" .. PresenceCache.GetTTL() .. "s)")
      PresenceCache.Rebuild()
    end
    Common.scheduleAfter(PresenceCache.GetTTL(), presenceTimerLoop)
  end

  Bootstrap._presenceTimerLoopStarted = Common.scheduleAfter(PresenceCache.GetTTL(), presenceTimerLoop) == true
end

function Presence.handlePlayerEnteringWorld(Bootstrap, deps)
  local ContentDetector = deps.getContentDetector()
  local wasMythic = Bootstrap._inMythicContent or false
  local isMythic = ContentDetector and ContentDetector.IsMythicRestricted(_G.GetInstanceInfo) or false
  local isCompetitive = ContentDetector and ContentDetector.IsCompetitiveContent(_G.GetInstanceInfo) or false
  deps.trace("PLAYER_ENTERING_WORLD wasMythic=" .. tostring(wasMythic) .. " isMythic=" .. tostring(isMythic))
  Bootstrap._inMythicContent = isMythic
  Bootstrap._inCompetitiveContent = isCompetitive
  Bootstrap._inEncounter = false
  if Bootstrap.syncChatFilters then
    Bootstrap.syncChatFilters()
  end
  -- Re-apply the R-key override: other addons often reprocess bindings on
  -- PLAYER_ENTERING_WORLD and may have cleared our SetOverrideBindingClick.
  if Bootstrap.runtime and Bootstrap.runtime.syncReplyKey then
    Bootstrap.runtime.syncReplyKey()
  end
  Common.notifyCompetitiveState(Bootstrap)

  if isMythic and not wasMythic then
    if Bootstrap.runtime and Bootstrap.runtime.suspend then
      Bootstrap.runtime.suspend()
    end
    deps.trace("mythic lockdown: suspended")
    return true
  elseif wasMythic and not isMythic then
    if Bootstrap.runtime and Bootstrap.runtime.resume then
      Bootstrap.runtime.resume()
    end
    deps.trace("mythic lockdown: resumed")
  elseif isMythic then
    return true
  end

  local PresenceCache = deps.getPresenceCache()
  if PresenceCache then
    schedulePresenceRefresh(Bootstrap, PresenceCache, deps)
  elseif Bootstrap.runtime and Bootstrap.runtime.refreshWindow then
    Common.scheduleAfter(2, function()
      Bootstrap.runtime.refreshWindow()
    end)
  end

  return true
end

function Presence.handlePresenceInvalidation(Bootstrap, event, deps)
  local PresenceCache = deps.getPresenceCache()
  if PresenceCache == nil then
    return true
  end

  PresenceCache.Invalidate()
  deps.trace("PresenceCache: invalidated by " .. event)

  if not Bootstrap._presenceRebuildPending then
    Bootstrap._presenceRebuildPending = true
    Common.scheduleAfter(2, function()
      Bootstrap._presenceRebuildPending = false
      if Bootstrap._inMythicContent then
        return
      end
      deps.trace("PresenceCache: debounced rebuild after " .. event)
      PresenceCache.Rebuild()
    end)
  end

  return true
end

ns.BootstrapLifecycleHandlersPresence = Presence
return Presence
