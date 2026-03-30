local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local function loadModule(name, key)
  if ns[key] then
    return ns[key]
  end

  if type(require) == "function" then
    local ok, loaded = pcall(require, name)
    if ok then
      return loaded
    end
  end

  error(key .. " module not available")
end

if ns.Loader then
  loadModule = ns.Loader.LoadModule
elseif type(require) == "function" then
  local ok, Loader = pcall(require, "WhisperMessenger.Core.Loader")
  if ok and Loader then
    loadModule = Loader.LoadModule
  end
end

local Diagnostics = {}
ns.BootstrapDiagnostics = Diagnostics

function Diagnostics.Create(deps)
  deps = deps or {}

  local runtime = deps.runtime or {}
  local trace = deps.trace or function() end
  local presenceCache = deps.presenceCache or loadModule("WhisperMessenger.Model.PresenceCache", "PresenceCache")
  local getWindow = deps.getWindow or function()
    return nil
  end
  local isWindowVisible = deps.isWindowVisible or function()
    return false
  end
  local updateAddOnMemoryUsage = deps.updateAddOnMemoryUsage or _G.UpdateAddOnMemoryUsage
  local getAddOnMemoryUsage = deps.getAddOnMemoryUsage or _G.GetAddOnMemoryUsage
  local collectgarbageFn = deps.collectgarbage or collectgarbage
  local resolvedAddonName = deps.addonName or addonName
  local prevSnapshot = nil

  local function countRegions(frame)
    local count = 0
    if frame.GetRegions then
      local regions = { frame:GetRegions() }
      count = count + #regions
    end
    if frame.GetChildren then
      local children = { frame:GetChildren() }
      count = count + #children
    end
    return count
  end

  local diagnostics = {}

  function diagnostics.debugContact(conversationKey)
    if conversationKey == nil then
      return
    end

    local store = runtime.store or {}
    local conversations = store.conversations or {}
    local conversation = conversations[conversationKey]
    if conversation == nil then
      return
    end

    local guid = conversation.guid
    local availabilityByGUID = runtime.availabilityByGUID or {}
    local cached = guid and availabilityByGUID[guid] or nil
    local presence = guid and presenceCache.GetPresence(guid) or nil
    local isBN = conversation.channel == "BN"

    trace("--- Contact Debug ---")
    trace("[stored] conversation data from message history:")
    trace("  key:            " .. tostring(conversationKey))
    trace("  displayName:    " .. tostring(conversation.displayName))
    trace("  contactDisplayName:" .. tostring(conversation.contactDisplayName))
    trace("  battleTag:      " .. tostring(conversation.battleTag))
    trace("  channel:        " .. tostring(conversation.channel))
    trace("  guid:           " .. tostring(guid))
    trace("  bnetAccountID:  " .. tostring(conversation.bnetAccountID))
    trace("  gameAccountName:" .. tostring(conversation.gameAccountName))
    trace("  className:      " .. tostring(conversation.className))
    trace("  classTag:       " .. tostring(conversation.classTag))
    trace("  raceName:       " .. tostring(conversation.raceName))
    trace("  raceTag:        " .. tostring(conversation.raceTag))
    trace("  faction:        " .. tostring(conversation.factionName))
    trace("  unreadCount:    " .. tostring(conversation.unreadCount))
    trace("  lastActivityAt: " .. tostring(conversation.lastActivityAt))
    trace("  lastPreview:    " .. tostring(conversation.lastPreview))
    local activeStatus = conversation.activeStatus
    trace("  activeStatus:   " .. (activeStatus and (activeStatus.eventName .. ": " .. activeStatus.text) or "nil"))
    trace("[cached] runtime availability (from CAN_LOCAL_WHISPER_TARGET_RESPONSE):")
    trace("  cachedStatus:   " .. (cached and cached.status or "nil"))
    trace("  canWhisper:     " .. (cached and tostring(cached.canWhisper) or "nil"))
    trace("  rawStatusCode:  " .. (cached and tostring(cached.rawStatus) or "nil"))
    trace("[presenceCache] guild/community presence:")
    trace("  presence:       " .. tostring(presence))
    trace("  cacheStale:     " .. tostring(presenceCache.IsStale()))
    local freshPresence = guid and presenceCache.RefreshPresence(guid) or nil
    trace("  freshPresence:  " .. tostring(freshPresence))
    trace("[runtime] derived / environment:")
    trace("  localFaction:   " .. tostring(runtime.localFaction))
    trace("  isBattleNet:    " .. tostring(isBN))
    trace("  sameFaction:    " .. tostring(conversation.factionName == runtime.localFaction))

    if isBN and conversation.bnetAccountID then
      local bnetResolver = deps.bnetResolver or loadModule("WhisperMessenger.Transport.BNetResolver", "BNetResolver")
      local accountInfo =
        bnetResolver.ResolveAccountInfo(runtime.bnetApi, conversation.bnetAccountID, guid, conversation.displayName)
      trace("[live] BNet API (ResolveAccountInfo):")
      if accountInfo then
        local gi = accountInfo.gameAccountInfo
        trace("  bn.battleTag: " .. tostring(accountInfo.battleTag))
        trace("  bn.isOnline:  " .. tostring(accountInfo.isOnline))
        trace("  bn.isAFK:     " .. tostring(accountInfo.isAFK))
        trace("  bn.isDND:     " .. tostring(accountInfo.isDND))
        if gi then
          trace("  game.isOnline:  " .. tostring(gi.isOnline))
          trace("  game.isGameAFK: " .. tostring(gi.isGameAFK))
          trace("  game.isGameBusy:" .. tostring(gi.isGameBusy))
          trace("  game.charName:  " .. tostring(gi.characterName))
          trace("  game.faction:   " .. tostring(gi.factionName))
        else
          trace("  gameAccountInfo: nil")
        end
      else
        trace("  accountInfo:  nil")
      end

      if guid and runtime.bnetApi and type(runtime.bnetApi.GetAccountInfoByGUID) == "function" then
        local ok, altInfo = pcall(runtime.bnetApi.GetAccountInfoByGUID, guid)
        trace("[live] BNet API (GetAccountInfoByGUID):")
        if ok and altInfo then
          local gameAccountInfo = altInfo.gameAccountInfo
          trace("  alt.bnetAcctID: " .. tostring(altInfo.bnetAccountID))
          trace("  alt.battleTag: " .. tostring(altInfo.battleTag))
          trace("  alt.isOnline: " .. tostring(altInfo.isOnline))
          trace("  alt.isAFK:    " .. tostring(altInfo.isAFK))
          trace("  alt.isDND:    " .. tostring(altInfo.isDND))
          if gameAccountInfo then
            trace("  alt.game.isOnline:  " .. tostring(gameAccountInfo.isOnline))
            trace("  alt.game.charName:  " .. tostring(gameAccountInfo.characterName))
            trace("  alt.game.faction:   " .. tostring(gameAccountInfo.factionName))
          end
        else
          trace("  alt(ByGUID): nil or error")
        end
      end

      if
        runtime.bnetApi
        and type(runtime.bnetApi.GetFriendNumGameAccounts) == "function"
        and type(runtime.bnetApi.GetNumFriends) == "function"
        and type(runtime.bnetApi.GetFriendAccountInfo) == "function"
      then
        trace("[live] BNet API (GetFriendNumGameAccounts):")
        local debugFriendIndex
        local okNumFriends, numFriends = pcall(runtime.bnetApi.GetNumFriends)
        if okNumFriends and numFriends then
          for index = 1, numFriends do
            local okFriend, friendInfo = pcall(runtime.bnetApi.GetFriendAccountInfo, index)
            if okFriend and friendInfo and friendInfo.bnetAccountID == conversation.bnetAccountID then
              debugFriendIndex = index
              break
            end
          end
        end
        if debugFriendIndex then
          local okAccounts, numAccounts = pcall(runtime.bnetApi.GetFriendNumGameAccounts, debugFriendIndex)
          if okAccounts and numAccounts then
            trace("  numGameAccounts: " .. tostring(numAccounts))
          else
            trace("  numGameAccounts: nil or error")
          end
        else
          trace("  numGameAccounts: (friendIndex not found)")
        end
      end
    end

    local testContacts = {
      {
        guid = guid,
        channel = conversation.channel or "WOW",
        factionName = conversation.factionName,
        bnetAccountID = conversation.bnetAccountID,
      },
    }
    local contactEnricher = deps.contactEnricher or loadModule("WhisperMessenger.Model.ContactEnricher", "ContactEnricher")
    contactEnricher.EnrichContactsAvailability(testContacts, runtime)
    local enriched = testContacts[1].availability
    trace("[enriched] final availability (what the UI displays):")
    if enriched then
      trace("  status:     " .. tostring(enriched.status))
      trace("  canWhisper: " .. tostring(enriched.canWhisper))
    else
      trace("  availability: nil (no data)")
    end
    trace("--- End Debug ---")
  end

  function diagnostics.memoryReport()
    local fmt = string.format
    local pairsFn = pairs

    trace("=== WhisperMessenger Memory Report ===")

    local preGcKB = 0
    if type(updateAddOnMemoryUsage) == "function" then
      updateAddOnMemoryUsage()
      if type(getAddOnMemoryUsage) == "function" then
        preGcKB = getAddOnMemoryUsage(resolvedAddonName) or 0
      end
    end

    local postGcKB = 0
    if type(collectgarbageFn) == "function" then
      collectgarbageFn("collect")
    end
    if type(updateAddOnMemoryUsage) == "function" then
      updateAddOnMemoryUsage()
      if type(getAddOnMemoryUsage) == "function" then
        postGcKB = getAddOnMemoryUsage(resolvedAddonName) or 0
      end
    end

    local garbageKB = preGcKB - postGcKB
    trace("  WM pre-GC:  " .. fmt("%.1f", preGcKB) .. " KB  (game menu sees this)")
    trace("  WM post-GC: " .. fmt("%.1f", postGcKB) .. " KB  (actual footprint)")
    if garbageKB > 0 then
      trace("  Garbage:    " .. fmt("%.1f", garbageKB) .. " KB  (transient, reclaimable)")
    end
    if type(collectgarbageFn) == "function" then
      trace("  Lua total:  " .. fmt("%.0f", collectgarbageFn("count")) .. " KB")
    end
    local wmKB = postGcKB

    local conversations = runtime.store and runtime.store.conversations or {}
    local convCount = 0
    local totalMessages = 0
    local totalUnread = 0
    local largestConv = 0
    local largestConvKey = "none"
    for key, conversation in pairsFn(conversations) do
      convCount = convCount + 1
      local msgCount = #(conversation.messages or {})
      totalMessages = totalMessages + msgCount
      totalUnread = totalUnread + (conversation.unreadCount or 0)
      if msgCount > largestConv then
        largestConv = msgCount
        largestConvKey = key
      end
    end
    trace("  Conversations: " .. convCount .. "  Messages: " .. totalMessages .. "  Unread: " .. totalUnread)
    if largestConv > 0 then
      trace("  Largest: " .. largestConv .. " msgs (" .. largestConvKey .. ")")
    end

    local availabilityByGUID = runtime.availabilityByGUID or {}
    local availCount = 0
    for _ in pairsFn(availabilityByGUID) do
      availCount = availCount + 1
    end
    local pendingOutgoing = runtime.pendingOutgoing or {}
    local pendingCount = 0
    for _ in pairsFn(pendingOutgoing) do
      pendingCount = pendingCount + 1
    end
    trace("  Avail cache: " .. availCount .. "  Pending: " .. pendingCount)

    local window = getWindow()
    trace("  Window: " .. (window and (isWindowVisible() and "visible" or "hidden") or "not created"))

    local snapshot = { wmKB = wmKB, pools = {} }

    if window and window.conversation and window.conversation.transcript then
      local contentFrame = window.conversation.transcript.content
      if contentFrame and contentFrame._activeFrames then
        local activeCount = #contentFrame._activeFrames
        local freeCount = contentFrame._freeFrames and #contentFrame._freeFrames or 0
        local totalFrames = activeCount + freeCount
        local totalRegions = 0

        for _, frame in ipairs(contentFrame._activeFrames) do
          totalRegions = totalRegions + countRegions(frame)
        end
        if contentFrame._freeFrames then
          for _, frame in ipairs(contentFrame._freeFrames) do
            totalRegions = totalRegions + countRegions(frame)
          end
        end

        snapshot.pools = { active = activeCount, free = freeCount, regions = totalRegions }
        trace("  --- Frame Pool ---")
        trace(
          "  Frames: "
            .. activeCount
            .. " active / "
            .. freeCount
            .. " free / "
            .. totalFrames
            .. " total  |  regions: "
            .. totalRegions
        )
      end
    end

    if prevSnapshot then
      trace("  --- Delta from last /wmsg mem ---")
      local deltaKB = wmKB - prevSnapshot.wmKB
      trace("  WM memory: " .. (deltaKB >= 0 and "+" or "") .. fmt("%.1f", deltaKB) .. " KB")
      if snapshot.pools.active and prevSnapshot.pools.active then
        local frameDelta = (snapshot.pools.active + snapshot.pools.free)
          - (prevSnapshot.pools.active + prevSnapshot.pools.free)
        local regionDelta = snapshot.pools.regions - prevSnapshot.pools.regions
        if frameDelta ~= 0 or regionDelta ~= 0 then
          trace(
            "  Frames: "
              .. (frameDelta >= 0 and "+" or "")
              .. frameDelta
              .. "  regions: "
              .. (regionDelta >= 0 and "+" or "")
              .. regionDelta
          )
        end
      end
    end

    prevSnapshot = snapshot
    trace("=== End Memory Report ===")
  end

  return diagnostics
end

return Diagnostics
