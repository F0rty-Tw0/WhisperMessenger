local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local ChannelMessageStore = ns.ChannelMessageStore or require("WhisperMessenger.Model.ChannelMessageStore")
local BNetRekey = ns.BootstrapLifecycleHandlersBNetRekey or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.BNetRekey")
local LockdownReplay = ns.BootstrapLockdownReplay or require("WhisperMessenger.Core.Bootstrap.LockdownReplay")
local RestrictedActions = ns.BootstrapRestrictedActions or require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local OnlineNotify = ns.BootstrapLifecycleHandlersOnlineNotify or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.OnlineNotify")
local ZoneNotify = ns.BootstrapLifecycleHandlersZoneNotify or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.ZoneNotify")
-- stylua: ignore
local ZoneRosterPoll = ns.BootstrapLifecycleHandlersZoneRosterPoll or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.ZoneRosterPoll")
-- stylua: ignore
local ScanFieldDiff = ns.BootstrapLifecycleHandlersScanFieldDiff or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.ScanFieldDiff")
-- stylua: ignore
local ScanSignature = ns.BootstrapLifecycleHandlersScanSignature or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.ScanSignature")
-- stylua: ignore
local StaleRestrictions = ns.BootstrapLifecycleHandlersStaleRestrictions or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.StaleRestrictions")

local Presence = {}

-- "Clear on logout" leaves no chat history in the saved variables.
function Presence.handlePlayerLogout(Bootstrap)
  local runtime = Bootstrap.runtime
  local settings = runtime and runtime.accountState and runtime.accountState.settings
  if not (settings and settings.clearOnLogout) then
    return true
  end

  -- The removal hook clears a selection together with its chat; a saved
  -- selection can also name a chat that expired while offline.
  runtime.activeConversationKey = nil
  if runtime.characterState then
    runtime.characterState.activeConversationKey = nil
  end
  -- Channel lines kept to show above a new whisper are saved history too.
  if runtime.channelMessageStore then
    ChannelMessageStore.Clear(runtime.channelMessageStore)
  end
  -- The hook runs session cleanup per chat. If any of it fails, the chats
  -- must still not reach the saved variables, so drop what is left.
  pcall(Store.RemoveAll, runtime.store)
  local conversations = runtime.store.conversations
  for key in pairs(conversations) do
    conversations[key] = nil
  end
  return true
end

local function isWindowHidden(runtime)
  return runtime.refreshWindow ~= nil and runtime.isWindowVisible ~= nil and not runtime.isWindowVisible()
end

-- A closed window (hidden) shows only the icon badges and preview, so
-- rebuild just the cards this scan changed (the preview's class colour
-- follows the friend's character), and nothing when none changed. An open
-- window rebuilds every card and the header, but only when the scan changed
-- a stored field or a friend's live state (liveChanged: online, away, the
-- character and its zone). Opening the window later rebuilds it anyway, and
-- a change the scan could not tell is drawn by the status tick
-- (runtime.bnetRepaintPending).
local function refreshAfterBNetScan(Bootstrap, changedKeys, liveChanged, hidden)
  local runtime = Bootstrap.runtime
  if hidden then
    if next(changedKeys) ~= nil then
      runtime.refreshWindow(nil, changedKeys)
    end
    return
  end
  if liveChanged or next(changedKeys) ~= nil then
    Common.refreshRuntimeWindow(Bootstrap)
  end
end

-- The account an open window draws for a conversation: the resolver's
-- answer, which looks past the friend-list entry's primary game account (the
-- Battle.net app, another game) for one in WoW and falls back to the stored
-- character GUID. friend nil (battleTag renamed, or no longer a friend): the
-- stored account ID, as the window reads it.
local function resolveShownAccount(BNetResolver, bnetApi, conversation, friend, passCache)
  local bnetAccountID = conversation.bnetAccountID
  if friend then
    bnetAccountID = friend.bnetAccountID
  end
  return BNetResolver.ResolveAccountInfo(bnetApi, bnetAccountID, conversation.guid, conversation.battleTag, passCache)
end

local function refreshBNetConversations(Bootstrap, deps)
  if Bootstrap.runtime == nil then
    return
  end
  -- Marked again before anything is read: a status tick may have drawn the
  -- window since the event, and a scan that fails half way must still be
  -- followed by a draw.
  Bootstrap.runtime.bnetRepaintPending = true

  local BNetResolver = deps.loadModule("WhisperMessenger.Transport.BNetResolver", "BNetResolver")
  local BNetStatus = deps.loadModule("WhisperMessenger.Model.ContactEnricher.BNetStatus", "ContactEnricherBNetStatus")
  local friendMap = BNetResolver.ScanFriendList(Bootstrap.runtime.bnetApi)
  -- Serves every lookup of this scan from one more friend-list walk.
  local passCache = BNetResolver.NewPassCache()

  local Identity = deps.loadModule("WhisperMessenger.Model.Identity", "Identity")
  local maxMessages = Bootstrap.runtime.store.config and Bootstrap.runtime.store.config.maxMessagesPerConversation
  local mappings = BNetRekey.RekeyOrphans(Bootstrap.runtime.store, friendMap, Identity, maxMessages)
  BNetRekey.ApplyMappings(Bootstrap.runtime, mappings)

  -- A rekey moved or merged these threads before the field check below runs.
  local changedKeys = {}
  for _, newKey in pairs(mappings) do
    changedKeys[newKey] = true
  end
  -- Session state: what the last scan saw live for each conversation's
  -- friend. Only an open window draws it, so a scan under a closed window
  -- resolves and signs nothing and drops the state: the first scan after the
  -- window opens starts fresh and redraws.
  local hidden = isWindowHidden(Bootstrap.runtime)
  local signatures = nil
  if not hidden then
    signatures = Bootstrap.runtime.bnetScanSignatures or {}
  end
  Bootstrap.runtime.bnetScanSignatures = signatures
  local liveChanged = false
  for key, conversation in pairs(Bootstrap.runtime.store.conversations) do
    if conversation.channel == "BN" and conversation.battleTag then
      local friend = friendMap[conversation.battleTag]
      if friend then
        ScanFieldDiff.Capture(conversation)
        conversation.bnetAccountID = friend.bnetAccountID
        -- Records a "Notify when online" friend's state from this existing
        -- scan, so their next online event is a real change.
        if conversation.notifyOnline == true then
          OnlineNotify.Observe(Bootstrap.runtime, key, conversation, BNetStatus.IsOnline(friend.accountInfo))
        end
        local gameInfo = friend.accountInfo and friend.accountInfo.gameAccountInfo
        -- Outside WoW the areaName is stale, so it counts as no zone.
        if conversation.notifyZone == true then
          ZoneNotify.Observe(Bootstrap.runtime, conversation, BNetStatus.IsInWoW(gameInfo) and gameInfo.areaName or nil)
        end
        BNetStatus.ApplyGameInfoMetadata(conversation, gameInfo, Bootstrap.runtime)
        if gameInfo and gameInfo.characterName and gameInfo.characterName ~= "" then
          local realmSuffix = (gameInfo.realmName and gameInfo.realmName ~= "") and ("-" .. gameInfo.realmName) or ""
          conversation.gameAccountName = gameInfo.characterName .. realmSuffix
        end
        if ScanFieldDiff.Changed(conversation) then
          changedKeys[key] = true
        end
      end
      -- Last, so a lookup that raises cannot skip the notify bookkeeping
      -- above for this conversation.
      if signatures then
        local shown = resolveShownAccount(BNetResolver, Bootstrap.runtime.bnetApi, conversation, friend, passCache)
        if ScanSignature.Update(signatures, key, shown) then
          liveChanged = true
        end
      end
    end
  end

  if signatures then
    ScanSignature.Prune(signatures, Bootstrap.runtime.store.conversations)
  end

  refreshAfterBNetScan(Bootstrap, changedKeys, liveChanged, hidden)
end

function Presence.handleBNetFriendEvent(Bootstrap, deps)
  if Bootstrap.runtime == nil then
    return true
  end
  -- The open window owes a full draw from here on. The scan below draws it
  -- when it can tell a change; otherwise the window's status tick does
  -- (WindowCoordinator), and either full draw clears the mark.
  Bootstrap.runtime.bnetRepaintPending = true

  -- BN_FRIEND_INFO_CHANGED fires in bursts (one per presence change, often
  -- several per second with a large friend list), and each scan walks every
  -- friend and every conversation. Debounce into one deferred scan, same as
  -- handlePresenceInvalidation; run synchronously when timers are
  -- unavailable so nothing is dropped.
  if Bootstrap._bnetFriendRefreshPending then
    return true
  end
  Bootstrap._bnetFriendRefreshPending = true
  local scheduled = Common.scheduleAfter(2, function()
    Bootstrap._bnetFriendRefreshPending = false
    refreshBNetConversations(Bootstrap, deps)
  end)
  if not scheduled then
    Bootstrap._bnetFriendRefreshPending = false
    refreshBNetConversations(Bootstrap, deps)
  end
  return true
end

-- One deferred rebuild after login builds the guild/community index. From
-- then on presence is read per contact, so there is no repeating refresh loop
-- re-enumerating every member every TTL.
local function schedulePresenceRefresh(Bootstrap, PresenceCache)
  Common.scheduleAfter(2, function()
    if RestrictedActions.For(Bootstrap).flag("mythic") then
      return
    end
    PresenceCache.Rebuild()
    Common.refreshRuntimeWindow(Bootstrap)
  end)
end

function Presence.handlePlayerEnteringWorld(Bootstrap, deps)
  StaleRestrictions.Clear(Bootstrap)
  local ContentDetector = deps.getContentDetector()
  local restrictions = RestrictedActions.For(Bootstrap)
  local wasMythic = restrictions.flag("mythic")
  local isMythic = ContentDetector and ContentDetector.IsMythicRestricted(_G.GetInstanceInfo) or false
  local isCompetitive = ContentDetector and ContentDetector.IsCompetitiveContent(_G.GetInstanceInfo) or false
  restrictions.setFlag("mythic", isMythic)
  restrictions.setFlag("competitive", isCompetitive)
  restrictions.setFlag("encounter", false)
  if Bootstrap.syncChatFilters then
    Bootstrap.syncChatFilters()
  end
  -- Re-apply the R-key override: other addons often reprocess bindings on
  -- PLAYER_ENTERING_WORLD and may have cleared our SetOverrideBindingClick.
  if Bootstrap.runtime and Bootstrap.runtime.syncReplyKey then
    Bootstrap.runtime.syncReplyKey()
  end
  -- resume() clears the notice, so it runs before the notice is decided.
  if wasMythic and not isMythic and Bootstrap.runtime and Bootstrap.runtime.resume then
    Bootstrap.runtime.resume()
  end
  Common.notifyCompetitiveState(Bootstrap)

  if isMythic and not wasMythic then
    if Bootstrap.runtime and Bootstrap.runtime.suspend then
      Bootstrap.runtime.suspend()
    end
    return true
  elseif isMythic then
    return true
  end
  LockdownReplay.Kick(Bootstrap.runtime)
  ZoneRosterPoll.Start(Bootstrap.runtime)

  local PresenceCache = deps.getPresenceCache()
  if PresenceCache then
    schedulePresenceRefresh(Bootstrap, PresenceCache)
  elseif Bootstrap.runtime and Bootstrap.runtime.refreshWindow then
    Common.scheduleAfter(2, function()
      Bootstrap.runtime.refreshWindow()
    end)
  end

  return true
end

local function checkZones(Bootstrap, PresenceCache)
  if ZoneNotify.handleRosterUpdate(Bootstrap, PresenceCache) then
    Common.refreshRuntimeWindow(Bootstrap)
  end
end

-- One "Notify when they change zone" check per burst, same debounce as the
-- Battle.net friend refresh; synchronous when timers are unavailable.
-- Nothing armed: no timer, no check.
local function scheduleZoneCheck(Bootstrap, PresenceCache)
  if Bootstrap._zoneCheckPending or not ZoneNotify.HasArmedGuildContact(Bootstrap.runtime) then
    return
  end
  Bootstrap._zoneCheckPending = true
  local scheduled = Common.scheduleAfter(2, function()
    Bootstrap._zoneCheckPending = false
    checkZones(Bootstrap, PresenceCache)
  end)
  if not scheduled then
    Bootstrap._zoneCheckPending = false
    checkZones(Bootstrap, PresenceCache)
  end
end

-- Roster and club membership events fire in bursts. Presence is marked stale
-- at once, with no rescan: the next per-contact read decides whether one is
-- worth it. Armed zone-watch contacts get that read once the burst settles,
-- never in mythic content (same rule as the login rebuild).
function Presence.handlePresenceInvalidation(Bootstrap, deps)
  local PresenceCache = deps.getPresenceCache()
  if PresenceCache == nil then
    return true
  end

  PresenceCache.Invalidate()
  if not RestrictedActions.For(Bootstrap).flag("mythic") then
    scheduleZoneCheck(Bootstrap, PresenceCache)
  end

  return true
end

ns.BootstrapLifecycleHandlersPresence = Presence
return Presence
