local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local LifecycleHandlers = {}

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
    Bootstrap._inMythicContent = true
    if Bootstrap.runtime and Bootstrap.runtime.suspend then
      Bootstrap.runtime.suspend()
    end
    deps.trace("mythic lockdown: M+ started")
    return true
  end

  if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    Bootstrap._inMythicContent = false
    if Bootstrap.runtime and Bootstrap.runtime.resume then
      Bootstrap.runtime.resume()
    end
    deps.trace(event == "CHALLENGE_MODE_COMPLETED" and "mythic lockdown: M+ completed" or "mythic lockdown: M+ reset")
    return true
  end

  return false
end

local function handleZoneChangedNewArea(Bootstrap, deps)
  local ContentDetector = deps.getContentDetector()

  -- Update competitive content flag on every zone change so the chat
  -- filter bypasses correctly when entering/leaving PvP or arenas.
  if Bootstrap._inCompetitiveContent or Bootstrap._inMythicContent then
    local isCompetitive = ContentDetector and ContentDetector.IsCompetitiveContent(_G.GetInstanceInfo) or false
    Bootstrap._inCompetitiveContent = isCompetitive
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
  end

  if not Bootstrap._inMythicContent then
    return true
  end

  local isMythic = ContentDetector and ContentDetector.IsMythicRestricted(_G.GetInstanceInfo) or false
  deps.trace("ZONE_CHANGED_NEW_AREA wasMythic=true isMythic=" .. tostring(isMythic))
  if not isMythic then
    Bootstrap._inMythicContent = false
    if Bootstrap.runtime and Bootstrap.runtime.resume then
      Bootstrap.runtime.resume()
    end

    local PresenceCache = deps.getPresenceCache()
    if PresenceCache then
      scheduleAfter(2, function()
        if Bootstrap._inMythicContent then
          return
        end
        deps.trace("PresenceCache: rebuild after mythic exit")
        PresenceCache.Rebuild()
        refreshRuntimeWindow(Bootstrap)
      end)
    end

    deps.trace("mythic lockdown: resumed via zone change")
  end

  return true
end

local function schedulePresenceRefresh(Bootstrap, PresenceCache, deps)
  scheduleAfter(2, function()
    if Bootstrap._inMythicContent then
      return
    end
    deps.trace("PresenceCache: initial rebuild (PLAYER_ENTERING_WORLD +2s)")
    PresenceCache.Rebuild()
    refreshRuntimeWindow(Bootstrap)
  end)

  local function presenceTimerLoop()
    if not Bootstrap._inMythicContent and PresenceCache.IsStale() then
      deps.trace("PresenceCache: timer rebuild (TTL=" .. PresenceCache.GetTTL() .. "s)")
      PresenceCache.Rebuild()
    end
    scheduleAfter(PresenceCache.GetTTL(), presenceTimerLoop)
  end

  scheduleAfter(PresenceCache.GetTTL(), presenceTimerLoop)
end

local function handlePlayerEnteringWorld(Bootstrap, deps)
  local ContentDetector = deps.getContentDetector()
  local wasMythic = Bootstrap._inMythicContent or false
  local isMythic = ContentDetector and ContentDetector.IsMythicRestricted(_G.GetInstanceInfo) or false
  local isCompetitive = ContentDetector and ContentDetector.IsCompetitiveContent(_G.GetInstanceInfo) or false
  deps.trace("PLAYER_ENTERING_WORLD wasMythic=" .. tostring(wasMythic) .. " isMythic=" .. tostring(isMythic))
  Bootstrap._inMythicContent = isMythic
  Bootstrap._inCompetitiveContent = isCompetitive
  if Bootstrap.syncChatFilters then
    Bootstrap.syncChatFilters()
  end

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
    scheduleAfter(2, function()
      Bootstrap.runtime.refreshWindow()
    end)
  end

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
      if Bootstrap._inMythicContent then
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
