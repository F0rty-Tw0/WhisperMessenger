local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local LifecycleHandlers = {}

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local LockdownState = ns.BootstrapLockdownState or require("WhisperMessenger.Core.Bootstrap.LockdownState")

local MYTHIC_PAUSE_NOTICE =
  "Whispers are paused in Mythic content. Incoming and outgoing messages will resume after you leave."
local COMPETITIVE_NOTICE = "Whispers are paused in competitive content. Messages will resume when you leave."

local function refreshRuntimeWindow(Bootstrap)
  if Bootstrap.runtime and Bootstrap.runtime.refreshWindow then
    Bootstrap.runtime.refreshWindow()
  end
end

local function scheduleAfter(delay, callback)
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    _G.C_Timer.After(delay, callback)
    return true
  end

  return false
end

local function drainSecretQueue(Bootstrap, deps)
  if FlavorCompat.InChatMessagingLockdown() then
    return
  end
  local EventBridge = deps.getEventBridge and deps.getEventBridge() or ns.BootstrapEventBridge
  if EventBridge and EventBridge.DrainSecretDeferredQueue and Bootstrap.runtime then
    local refreshFn = function()
      refreshRuntimeWindow(Bootstrap)
    end
    local drained = EventBridge.DrainSecretDeferredQueue(Bootstrap.runtime, refreshFn)
    -- After drain creates stub <lockdown> entries, schedule a delayed
    -- rescan of the default chat frame to replace placeholders with real
    -- content. The 2s delay gives Blizzard's chat frame time to finish
    -- processing the whisper events into its message buffer.
    if drained and drained > 0 then
      local STG = ns.BootstrapSecretTaintGuard
      if STG and type(STG.RescanChatForPlaceholders) == "function" then
        scheduleAfter(2, function()
          STG.RescanChatForPlaceholders(Bootstrap.runtime, refreshFn)
        end)
      end
    end
  end
end

local function ensureLockdown(Bootstrap)
  if Bootstrap.lockdown == nil then
    LockdownState.Initialize(Bootstrap)
  end
end

-- Writes runtime.messagingNotice from the current lockdown state. The source
-- determines which notice string wins: Mythic+ keeps its own "Mythic content"
-- wording; all other sources fall back to the generic competitive notice.
-- Skip while MythicSuspendController owns the notice (CHALLENGE_MODE_START),
-- because its suspend() call writes its own pause string.
local function notifyCompetitiveState(Bootstrap)
  ensureLockdown(Bootstrap)
  local isActive = Bootstrap.lockdown.active == true

  if Bootstrap.runtime and Bootstrap.lockdown.source ~= "CHALLENGE_MODE_START" then
    if isActive then
      Bootstrap.runtime.messagingNotice = COMPETITIVE_NOTICE
    else
      Bootstrap.runtime.messagingNotice = nil
    end
  end

  if type(Bootstrap.onCompetitiveStateChanged) == "function" then
    Bootstrap.onCompetitiveStateChanged(isActive)
  end
end

local function handleBNetFriendEvent(Bootstrap, deps)
  if Bootstrap.runtime == nil then
    return true
  end

  local BNetResolver = deps.loadModule("WhisperMessenger.Transport.BNetResolver", "BNetResolver")
  local friendMap = BNetResolver.ScanFriendList(Bootstrap.runtime.bnetApi)

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
          if gameInfo.characterName then
            conversation.gameAccountName = gameInfo.characterName
              .. (gameInfo.realmName and ("-" .. gameInfo.realmName) or "")
          end
        end
      end
    end
  end

  refreshRuntimeWindow(Bootstrap)
  return true
end

local function handlePlayerLogout(Bootstrap, deps)
  if Bootstrap.runtime then
    local settings = Bootstrap.runtime.accountState and Bootstrap.runtime.accountState.settings
    if settings and settings.clearOnLogout then
      for key in pairs(Bootstrap.runtime.store.conversations) do
        Bootstrap.runtime.store.conversations[key] = nil
      end
      deps.trace("clear on logout")
    end
  end

  return true
end

local function handleChallengeModeEvent(Bootstrap, event, deps)
  if event == "CHALLENGE_MODE_START" then
    ensureLockdown(Bootstrap)
    local changed, wasActive, isActive = LockdownState.Sync(Bootstrap, "CHALLENGE_MODE_START", deps)
    if changed and isActive and not wasActive and Bootstrap.runtime and Bootstrap.runtime.suspend then
      Bootstrap.runtime.suspend()
    end
    if Bootstrap.runtime and Bootstrap.lockdown.active then
      Bootstrap.runtime.messagingNotice = MYTHIC_PAUSE_NOTICE
    end
    deps.trace("mythic lockdown: M+ started")
    notifyCompetitiveState(Bootstrap)
    return true
  end

  if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    ensureLockdown(Bootstrap)
    local changed, wasActive, isActive = LockdownState.Sync(Bootstrap, event, deps)
    if changed and wasActive and not isActive and Bootstrap.runtime and Bootstrap.runtime.resume then
      Bootstrap.runtime.resume()
    end
    deps.trace(event == "CHALLENGE_MODE_COMPLETED" and "mythic lockdown: M+ completed" or "mythic lockdown: M+ reset")
    notifyCompetitiveState(Bootstrap)
    drainSecretQueue(Bootstrap, deps)
    return true
  end

  return false
end

local function handleEncounterEvent(Bootstrap, event, deps)
  if event == "ENCOUNTER_START" then
    -- ENCOUNTER_START fires for ALL raid/dungeon encounters regardless of
    -- difficulty (LFR/Normal/Heroic/Mythic/M+/dungeons). Only treat the
    -- encounter as a "competitive lockdown" when Blizzard's chat secrecy
    -- API actually has chat locked — otherwise we'd show the "paused"
    -- banner and lock indicator in regular raids where chat works fine.
    ensureLockdown(Bootstrap)
    LockdownState.Sync(Bootstrap, "ENCOUNTER_START", deps)
    if not Bootstrap.lockdown.active then
      return true
    end
    -- Set the global suspend flag so LinkHooks bail during locked raid pulls.
    -- Raid encounters lock chat but do NOT call runtime.suspend(); that keeps
    -- the window visible and avoids re-showing the full M+ "paused" overlay.
    _G._wmSuspended = true
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    deps.trace("encounter started")
    notifyCompetitiveState(Bootstrap)
    return true
  end

  if event == "ENCOUNTER_END" then
    ensureLockdown(Bootstrap)
    LockdownState.Sync(Bootstrap, "ENCOUNTER_END", deps)
    _G._wmSuspended = nil
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    deps.trace("encounter ended")
    notifyCompetitiveState(Bootstrap)
    drainSecretQueue(Bootstrap, deps)
    -- Blizzard's InChatMessagingLockdown() can stay true for a short window
    -- after ENCOUNTER_END fires. When that happens, the sync above saw no
    -- transition, the notice stayed stuck, and no other event fires to
    -- re-check until the player leaves the zone. Poll a few times over
    -- the next ~5s to catch the delayed clear and run the resume/drain
    -- path once it flips.
    if Bootstrap.lockdown.active then
      local attempts = 0
      local function retry()
        attempts = attempts + 1
        ensureLockdown(Bootstrap)
        local changed, wasActive, isActive = LockdownState.Sync(Bootstrap, "ENCOUNTER_END_RETRY", deps)
        if changed and wasActive and not isActive then
          if Bootstrap.syncChatFilters then
            Bootstrap.syncChatFilters()
          end
          notifyCompetitiveState(Bootstrap)
          drainSecretQueue(Bootstrap, deps)
          return
        end
        if attempts < 5 then
          scheduleAfter(1, retry)
        end
      end
      scheduleAfter(1, retry)
    end
    return true
  end

  return false
end

local function handleZoneChangedNewArea(Bootstrap, deps)
  ensureLockdown(Bootstrap)
  local changed, wasActive, isActive = LockdownState.Sync(Bootstrap, "ZONE_CHANGED_NEW_AREA", deps)

  if changed and wasActive and not isActive then
    -- Leaving mythic+: resume the runtime and kick the presence cache. Normal
    -- lockdown exits (raid/BG) don't need suspend/resume; their window state
    -- was never hidden, only the notice + _wmSuspended flag were managed by
    -- the encounter handler.
    if Bootstrap.runtime and Bootstrap.runtime.resume then
      Bootstrap.runtime.resume()
    end
    local PresenceCache = deps.getPresenceCache()
    if PresenceCache then
      scheduleAfter(2, function()
        if LockdownState.IsActive(Bootstrap) then
          return
        end
        deps.trace("PresenceCache: rebuild after lockdown exit")
        PresenceCache.Rebuild()
        refreshRuntimeWindow(Bootstrap)
      end)
    end
    deps.trace("lockdown: resumed via zone change")
  end

  if Bootstrap.syncChatFilters then
    Bootstrap.syncChatFilters()
  end

  if changed then
    notifyCompetitiveState(Bootstrap)
  end

  drainSecretQueue(Bootstrap, deps)
  return true
end

local function schedulePresenceRefresh(Bootstrap, PresenceCache, deps)
  scheduleAfter(2, function()
    if LockdownState.IsActive(Bootstrap) then
      return
    end
    deps.trace("PresenceCache: initial rebuild (PLAYER_ENTERING_WORLD +2s)")
    PresenceCache.Rebuild()
    refreshRuntimeWindow(Bootstrap)
  end)

  local function presenceTimerLoop()
    if not LockdownState.IsActive(Bootstrap) and PresenceCache.IsStale() then
      deps.trace("PresenceCache: timer rebuild (TTL=" .. PresenceCache.GetTTL() .. "s)")
      PresenceCache.Rebuild()
    end
    scheduleAfter(PresenceCache.GetTTL(), presenceTimerLoop)
  end

  scheduleAfter(PresenceCache.GetTTL(), presenceTimerLoop)
end

local function handlePlayerEnteringWorld(Bootstrap, deps)
  ensureLockdown(Bootstrap)
  local changed, wasActive, isActive = LockdownState.Sync(Bootstrap, "PLAYER_ENTERING_WORLD", deps)
  deps.trace("PLAYER_ENTERING_WORLD wasActive=" .. tostring(wasActive) .. " isActive=" .. tostring(isActive))

  if Bootstrap.syncChatFilters then
    Bootstrap.syncChatFilters()
  end
  notifyCompetitiveState(Bootstrap)

  if changed and isActive and not wasActive then
    if Bootstrap.runtime and Bootstrap.runtime.suspend then
      Bootstrap.runtime.suspend()
    end
    deps.trace("lockdown: suspended on PLAYER_ENTERING_WORLD")
    return true
  end

  if changed and wasActive and not isActive then
    if Bootstrap.runtime and Bootstrap.runtime.resume then
      Bootstrap.runtime.resume()
    end
    deps.trace("lockdown: resumed on PLAYER_ENTERING_WORLD")
  elseif isActive then
    return true
  end

  local PresenceCache = deps.getPresenceCache()
  if PresenceCache then
    schedulePresenceRefresh(Bootstrap, PresenceCache, deps)
  elseif Bootstrap.runtime and Bootstrap.runtime.refreshWindow then
    scheduleAfter(2, function()
      Bootstrap.runtime.refreshWindow()
    end)
  end

  drainSecretQueue(Bootstrap, deps)
  return true
end

local function handlePresenceInvalidation(Bootstrap, event, deps)
  local PresenceCache = deps.getPresenceCache()
  if PresenceCache == nil then
    return true
  end

  PresenceCache.Invalidate()
  deps.trace("PresenceCache: invalidated by " .. event)

  if not Bootstrap._presenceRebuildPending then
    Bootstrap._presenceRebuildPending = true
    scheduleAfter(2, function()
      Bootstrap._presenceRebuildPending = false
      if LockdownState.IsActive(Bootstrap) then
        return
      end
      deps.trace("PresenceCache: debounced rebuild after " .. event)
      PresenceCache.Rebuild()
    end)
  end

  return true
end

function LifecycleHandlers.Handle(Bootstrap, event, deps)
  if event == "BN_FRIEND_LIST_SIZE_CHANGED" or event == "BN_FRIEND_INFO_CHANGED" then
    return handleBNetFriendEvent(Bootstrap, deps)
  end

  if event == "PLAYER_LOGOUT" then
    return handlePlayerLogout(Bootstrap, deps)
  end

  if handleChallengeModeEvent(Bootstrap, event, deps) then
    return true
  end

  if handleEncounterEvent(Bootstrap, event, deps) then
    return true
  end

  if event == "ZONE_CHANGED_NEW_AREA" then
    return handleZoneChangedNewArea(Bootstrap, deps)
  end

  if event == "PLAYER_ENTERING_WORLD" then
    return handlePlayerEnteringWorld(Bootstrap, deps)
  end

  if
    event == "GUILD_ROSTER_UPDATE"
    or event == "CLUB_MEMBER_UPDATED"
    or event == "CLUB_MEMBER_ADDED"
    or event == "CLUB_MEMBER_REMOVED"
  then
    return handlePresenceInvalidation(Bootstrap, event, deps)
  end

  return false
end

ns.BootstrapLifecycleHandlers = LifecycleHandlers
return LifecycleHandlers
