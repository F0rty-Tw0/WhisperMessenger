local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon
  or (type(require) == "function" and require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common"))
  or nil

local Presence = {}

function Presence.handlePlayerLogout(Bootstrap, deps)
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

function Presence.handleBNetFriendEvent(Bootstrap, deps)
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

  Common.refreshRuntimeWindow(Bootstrap)
  return true
end

local function schedulePresenceRefresh(Bootstrap, PresenceCache, deps)
  Common.scheduleAfter(2, function()
    if Bootstrap._inMythicContent then
      return
    end
    deps.trace("PresenceCache: initial rebuild (PLAYER_ENTERING_WORLD +2s)")
    PresenceCache.Rebuild()
    Common.refreshRuntimeWindow(Bootstrap)
  end)

  local function presenceTimerLoop()
    if not Bootstrap._inMythicContent and PresenceCache.IsStale() then
      deps.trace("PresenceCache: timer rebuild (TTL=" .. PresenceCache.GetTTL() .. "s)")
      PresenceCache.Rebuild()
    end
    Common.scheduleAfter(PresenceCache.GetTTL(), presenceTimerLoop)
  end

  Common.scheduleAfter(PresenceCache.GetTTL(), presenceTimerLoop)
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
