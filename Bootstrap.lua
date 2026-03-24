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

local function trace(...)
  if type(_G.print) == "function" then
    _G.print("[WM]", ...)
  end
end

if ns.trace then
  trace = ns.trace
elseif type(require) == "function" then
  local ok, loaded = pcall(require, "WhisperMessenger.Core.Trace")
  if ok and loaded then
    trace = loaded
  end
end

local Bootstrap = {}
ns.Bootstrap = Bootstrap

function Bootstrap.Initialize(factory, options)
  options = options or {}
  trace("initialize start")

  local RuntimeFactory = loadModule("WhisperMessenger.Core.Bootstrap.RuntimeFactory", "BootstrapRuntimeFactory")
  loadModule("WhisperMessenger.Core.Bootstrap.EventBridge", "BootstrapEventBridge") -- registers on ns
  local SendHandler = loadModule("WhisperMessenger.Core.Bootstrap.SendHandler", "BootstrapSendHandler")
  local MessengerWindow = loadModule("WhisperMessenger.UI.MessengerWindow", "MessengerWindow")
  local SavedState = loadModule("WhisperMessenger.Persistence.SavedState", "SavedState")
  local Schema = loadModule("WhisperMessenger.Persistence.Schema", "Schema")
  local SlashCommands = loadModule("WhisperMessenger.Core.SlashCommands", "SlashCommands")
  local ToggleIcon = loadModule("WhisperMessenger.UI.ToggleIcon", "ToggleIcon")
  local TableUtils = loadModule("WhisperMessenger.Util.TableUtils", "TableUtils")
  local ContactEnricher = loadModule("WhisperMessenger.Model.ContactEnricher", "ContactEnricher")
  local ContactsList = loadModule("WhisperMessenger.UI.ContactsList", "ContactsList")
  local PresenceCache = loadModule("WhisperMessenger.Model.PresenceCache", "PresenceCache")

  local uiFactory = factory or _G
  local localProfileId = RuntimeFactory.ResolveLocalProfileId(options)
  local accountState, characterState =
    SavedState.Initialize(options.accountState, options.characterState, localProfileId)
  local defaultCharacterState = Schema.NewCharacterState()
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, localProfileId, options)

  -- Initialize guild/community presence cache
  local presenceTTL = (accountState.settings and accountState.settings.presenceRefreshInterval) or 30
  PresenceCache.Initialize(options.clubApi or _G.C_Club, {
    ttl = presenceTTL,
    now = options.now or function()
      return type(_G.time) == "function" and _G.time() or 0
    end,
  })

  local function buildContacts()
    return ContactsList.BuildItemsForProfile(runtime.accountState, runtime.localProfileId)
  end

  local window
  local icon

  local function setWindowVisible(nextVisible)
    if window == nil or window.frame == nil then
      return
    end

    trace("set visible=" .. tostring(nextVisible))
    if nextVisible then
      -- Rebuild presence cache on window open so all contacts show fresh statuses
      if PresenceCache then
        trace("PresenceCache: rebuild on window open")
        PresenceCache.Rebuild()
      end
      window.frame:Show()
    else
      window.frame:Hide()
    end
  end

  local function isWindowVisible()
    if window == nil or window.frame == nil then
      return false
    end

    if window.frame.IsShown then
      return window.frame:IsShown()
    end

    return window.frame.shown == true
  end

  -- Contact enrichment: ALWAYS runs regardless of window visibility.
  -- This is the critical path for keeping statuses fresh.
  local function refreshContacts()
    local freshContacts = buildContacts()
    -- Proactively request availability for WoW contacts with GUIDs we haven't queried yet
    local Gateway = loadModule("WhisperMessenger.Transport.WhisperGateway", "WhisperGateway")
    for _, item in ipairs(freshContacts) do
      if
        item.channel == "WOW"
        and item.guid
        and ContactEnricher.ShouldRequestAvailability(runtime.availabilityByGUID[item.guid])
      then
        Gateway.RequestAvailability(runtime.chatApi, item.guid)
      end
    end
    local nextState = ContactEnricher.BuildWindowSelectionState(runtime, freshContacts, buildContacts)

    -- Icon badge always updates
    if icon and icon.setUnreadCount then
      icon.setUnreadCount(TableUtils.sumBy(freshContacts, "unreadCount"))
    end

    return nextState
  end

  -- Full refresh: enriches contacts (always) + updates UI (only when visible)
  local function refreshWindow()
    local nextState = refreshContacts()

    if isWindowVisible() and window and window.refreshSelection then
      window.refreshSelection(nextState)
    end

    return nextState
  end

  local function debugContact(conversationKey)
    if conversationKey == nil then
      return
    end
    local conversation = runtime.store.conversations[conversationKey]
    if conversation == nil then
      return
    end

    local guid = conversation.guid
    local cached = guid and runtime.availabilityByGUID[guid] or nil
    local presence = guid and PresenceCache.GetPresence(guid) or nil
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
    trace("  cacheStale:     " .. tostring(PresenceCache.IsStale()))
    -- Targeted refresh to get live data for this contact
    local freshPresence = guid and PresenceCache.RefreshPresence(guid) or nil
    trace("  freshPresence:  " .. tostring(freshPresence))
    trace("[runtime] derived / environment:")
    trace("  localFaction:   " .. tostring(runtime.localFaction))
    trace("  isBattleNet:    " .. tostring(isBN))
    trace("  sameFaction:    " .. tostring(conversation.factionName == runtime.localFaction))

    if isBN and conversation.bnetAccountID then
      local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
      local accountInfo =
        BNetResolver.ResolveAccountInfo(runtime.bnetApi, conversation.bnetAccountID, guid, conversation.displayName)
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
      -- Try alternative API: GetAccountInfoByGUID
      if guid and runtime.bnetApi and type(runtime.bnetApi.GetAccountInfoByGUID) == "function" then
        local ok2, altInfo = pcall(runtime.bnetApi.GetAccountInfoByGUID, guid)
        trace("[live] BNet API (GetAccountInfoByGUID):")
        if ok2 and altInfo then
          local agi = altInfo.gameAccountInfo
          trace("  alt.bnetAcctID: " .. tostring(altInfo.bnetAccountID))
          trace("  alt.battleTag: " .. tostring(altInfo.battleTag))
          trace("  alt.isOnline: " .. tostring(altInfo.isOnline))
          trace("  alt.isAFK:    " .. tostring(altInfo.isAFK))
          trace("  alt.isDND:    " .. tostring(altInfo.isDND))
          if agi then
            trace("  alt.game.isOnline:  " .. tostring(agi.isOnline))
            trace("  alt.game.charName:  " .. tostring(agi.characterName))
            trace("  alt.game.faction:   " .. tostring(agi.factionName))
          end
        else
          trace("  alt(ByGUID): nil or error")
        end
      end
      -- Try alternative API: GetFriendNumGameAccounts + GetFriendGameAccountInfo
      if
        runtime.bnetApi
        and type(runtime.bnetApi.GetFriendNumGameAccounts) == "function"
        and type(runtime.bnetApi.GetNumFriends) == "function"
        and type(runtime.bnetApi.GetFriendAccountInfo) == "function"
      then
        trace("[live] BNet API (GetFriendNumGameAccounts):")
        -- Find the friendIndex by scanning the friend list for matching bnetAccountID
        local debugFriendIndex
        local okN, numFriends = pcall(runtime.bnetApi.GetNumFriends)
        if okN and numFriends then
          for i = 1, numFriends do
            local okF, fInfo = pcall(runtime.bnetApi.GetFriendAccountInfo, i)
            if okF and fInfo and fInfo.bnetAccountID == conversation.bnetAccountID then
              debugFriendIndex = i
              break
            end
          end
        end
        if debugFriendIndex then
          local ok3, numAccounts = pcall(runtime.bnetApi.GetFriendNumGameAccounts, debugFriendIndex)
          if ok3 and numAccounts then
            trace("  numGameAccounts: " .. tostring(numAccounts))
          else
            trace("  numGameAccounts: nil or error")
          end
        else
          trace("  numGameAccounts: (friendIndex not found)")
        end
      end
    end
    -- Show what the enricher actually computes for this contact
    local DebugEnricher = ns.ContactEnricher or require("WhisperMessenger.Model.ContactEnricher")
    local testContacts = {
      {
        guid = guid,
        channel = conversation.channel or "WOW",
        factionName = conversation.factionName,
        bnetAccountID = conversation.bnetAccountID,
      },
    }
    DebugEnricher.EnrichContactsAvailability(testContacts, runtime)
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

  local function selectConversation(conversationKey)
    local Gateway = loadModule("WhisperMessenger.Transport.WhisperGateway", "WhisperGateway")
    local Store = loadModule("WhisperMessenger.Model.ConversationStore", "ConversationStore")
    runtime.activeConversationKey = conversationKey
    characterState.activeConversationKey = conversationKey

    if conversationKey ~= nil and runtime.store.conversations[conversationKey] ~= nil then
      local conversation = runtime.store.conversations[conversationKey]
      Store.MarkRead(runtime.store, conversationKey)

      if conversation.guid then
        -- Targeted presence refresh for the clicked contact (fresh guild/community check)
        PresenceCache.RefreshPresence(conversation.guid)
      end
      if conversation.channel == "WOW" and conversation.guid then
        Gateway.RequestAvailability(runtime.chatApi, conversation.guid)
      end
    end

    debugContact(conversationKey)
    return refreshWindow()
  end

  local function findLatestUnreadKey()
    local freshContacts = buildContacts()
    -- Contacts are sorted by lastActivityAt desc, so first unread is latest
    for _, item in ipairs(freshContacts) do
      if (item.unreadCount or 0) > 0 then
        return item.conversationKey
      end
    end
    return nil
  end

  -- Lazy window creation: deferred to first toggle
  local function ensureWindow()
    if window then
      return
    end

    local contacts = buildContacts()
    local selectedState = ContactEnricher.BuildWindowSelectionState(runtime, contacts, buildContacts)

    window = MessengerWindow.Create(uiFactory, {
      contacts = contacts,
      selectedContact = selectedState.selectedContact,
      conversation = selectedState.conversation,
      status = selectedState.status,
      state = characterState.window,
      onSelectConversation = function(conversationKey)
        return selectConversation(conversationKey)
      end,
      onSend = function(payload)
        return SendHandler.HandleSend(runtime, payload, refreshWindow)
      end,
      onPositionChanged = function(nextState)
        characterState.window = TableUtils.copyState(nextState)
      end,
      onClose = function()
        setWindowVisible(false)
      end,
      onResetWindowPosition = function()
        local nextState = TableUtils.copyState(defaultCharacterState.window)
        characterState.window = nextState
        return nextState
      end,
      onClearAllChats = function()
        for key in pairs(runtime.store.conversations) do
          runtime.store.conversations[key] = nil
        end
        runtime.activeConversationKey = nil
        characterState.activeConversationKey = nil
      end,
      onPin = function(item)
        local Store = loadModule("WhisperMessenger.Model.ConversationStore", "ConversationStore")
        local key = item.conversationKey
        trace("onPin", "key=" .. tostring(key), "wasPinned=" .. tostring(item.pinned))
        if Store.IsPinned(runtime.store, key) then
          Store.Unpin(runtime.store, key)
        else
          Store.Pin(runtime.store, key)
        end
        refreshWindow()
      end,
      onRemove = function(item)
        local Store = loadModule("WhisperMessenger.Model.ConversationStore", "ConversationStore")
        local key = item.conversationKey
        trace("onRemove", "key=" .. tostring(key), "name=" .. tostring(item.displayName))
        Store.Remove(runtime.store, key)
        if runtime.activeConversationKey == key then
          runtime.activeConversationKey = nil
          characterState.activeConversationKey = nil
        end
        refreshWindow()
      end,
      onReorder = function(orders)
        local Store = loadModule("WhisperMessenger.Model.ConversationStore", "ConversationStore")
        trace("onReorder", "keys=" .. tostring(#orders or 0))
        for key, order in pairs(orders) do
          Store.SetSortOrder(runtime.store, key, order)
          trace("  sortOrder", "key=" .. tostring(key), "order=" .. tostring(order))
        end
        refreshWindow()
      end,
      onResetIconPosition = function()
        local nextState = TableUtils.copyState(defaultCharacterState.icon)
        characterState.icon = nextState

        if icon and icon.frame and icon.frame.SetPoint then
          local iconParent = icon.frame.parent or _G.UIParent
          icon.frame:SetPoint(nextState.anchorPoint, iconParent, nextState.relativePoint, nextState.x, nextState.y)
        end

        return nextState
      end,
      storeConfig = runtime.store.config,
      settingsConfig = (function()
        accountState.settings = accountState.settings or {}
        return accountState.settings
      end)(),
      onSettingChanged = function(key, value)
        accountState.settings[key] = value
        -- Update runtime store config for retention/limit settings
        if runtime.store.config[key] ~= nil then
          runtime.store.config[key] = value
        end
        -- Keep conversationMaxAge in sync with messageMaxAge
        if key == "messageMaxAge" then
          runtime.store.config.conversationMaxAge = value
        end
        trace("setting changed", key, tostring(value))
        -- Refresh contacts list for display-affecting settings
        if key == "hideMessagePreview" and runtime.refreshWindow then
          runtime.refreshWindow()
        end
        -- Re-evaluate icon badge/pulse when notification settings change
        if (key == "showUnreadBadge" or key == "badgePulse") and icon and icon.setUnreadCount then
          local freshContacts = buildContacts()
          icon.setUnreadCount(TableUtils.sumBy(freshContacts, "unreadCount"))
        end
      end,
    })

    if window.frame.Hide then
      window.frame:Hide()
    end

    runtime.window = window
  end

  local function toggle()
    ensureWindow()
    local nextVisible = not isWindowVisible()
    setWindowVisible(nextVisible)

    if nextVisible then
      -- Open the latest unread conversation, fall back to last active
      local unreadKey = findLatestUnreadKey()
      local targetKey = unreadKey or runtime.activeConversationKey
      if targetKey ~= nil then
        selectConversation(targetKey)
        return
      end
    end

    refreshWindow()
  end

  runtime.isConversationOpen = function(conversationKey)
    return isWindowVisible() and runtime.activeConversationKey == conversationKey
  end

  accountState.settings = accountState.settings or {}
  icon = ToggleIcon.Create(uiFactory, {
    state = characterState.icon,
    onToggle = toggle,
    onPositionChanged = function(nextState)
      characterState.icon = TableUtils.copyState(nextState)
    end,
    getShowUnreadBadge = function()
      return accountState.settings.showUnreadBadge ~= false
    end,
    getBadgePulse = function()
      return accountState.settings.badgePulse ~= false
    end,
  })

  -- Suppress whisper messages from the default chat frame (and their sound).
  -- Our addon provides its own messenger UI for whispers.
  -- We must preserve /r reply targets since the default handler won't run.
  if type(_G.ChatFrame_AddMessageEventFilter) == "function" then
    local setLastTell = _G.ChatEdit_SetLastTellTarget
    _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", function(_self, _event, _msg, sender)
      if type(setLastTell) == "function" and sender then
        setLastTell(sender, "WHISPER")
      end
      return true
    end)
    _G.ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", function(_self, _event, _msg, sender)
      if type(setLastTell) == "function" and sender then
        setLastTell(sender, "BN_WHISPER")
      end
      return true
    end)
  end

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

  local function memoryReport()
    local pairs = pairs
    local collectgarbage = collectgarbage
    local fmt = string.format

    trace("=== WhisperMessenger Memory Report ===")

    -- Pre-GC snapshot (what WoW's game menu shows)
    local preGcKB = 0
    if type(_G.UpdateAddOnMemoryUsage) == "function" then
      _G.UpdateAddOnMemoryUsage()
      if type(_G.GetAddOnMemoryUsage) == "function" then
        preGcKB = _G.GetAddOnMemoryUsage(addonName) or 0
      end
    end

    -- Force GC then measure again (actual footprint)
    local postGcKB = 0
    if type(collectgarbage) == "function" then
      collectgarbage("collect")
    end
    if type(_G.UpdateAddOnMemoryUsage) == "function" then
      _G.UpdateAddOnMemoryUsage()
      if type(_G.GetAddOnMemoryUsage) == "function" then
        postGcKB = _G.GetAddOnMemoryUsage(addonName) or 0
      end
    end

    local garbageKB = preGcKB - postGcKB
    trace("  WM pre-GC:  " .. fmt("%.1f", preGcKB) .. " KB  (game menu sees this)")
    trace("  WM post-GC: " .. fmt("%.1f", postGcKB) .. " KB  (actual footprint)")
    if garbageKB > 0 then
      trace("  Garbage:    " .. fmt("%.1f", garbageKB) .. " KB  (transient, reclaimable)")
    end
    if type(collectgarbage) == "function" then
      trace("  Lua total:  " .. fmt("%.0f", collectgarbage("count")) .. " KB")
    end
    local wmKB = postGcKB

    -- Data layer
    local convCount = 0
    local totalMessages = 0
    local totalUnread = 0
    local largestConv = 0
    local largestConvKey = "none"
    for key, conv in pairs(runtime.store.conversations) do
      convCount = convCount + 1
      local msgCount = #(conv.messages or {})
      totalMessages = totalMessages + msgCount
      totalUnread = totalUnread + (conv.unreadCount or 0)
      if msgCount > largestConv then
        largestConv = msgCount
        largestConvKey = key
      end
    end
    trace("  Conversations: " .. convCount .. "  Messages: " .. totalMessages .. "  Unread: " .. totalUnread)
    if largestConv > 0 then
      trace("  Largest: " .. largestConv .. " msgs (" .. largestConvKey .. ")")
    end

    -- Caches
    local availCount = 0
    for _ in pairs(runtime.availabilityByGUID) do
      availCount = availCount + 1
    end
    local pendingCount = 0
    for _ in pairs(runtime.pendingOutgoing) do
      pendingCount = pendingCount + 1
    end
    trace("  Avail cache: " .. availCount .. "  Pending: " .. pendingCount)

    -- Window state
    trace("  Window: " .. (window and (isWindowVisible() and "visible" or "hidden") or "not created"))

    -- Frame pool breakdown
    local snapshot = { wmKB = wmKB, pools = {} }

    if window and window.conversation and window.conversation.transcript then
      local cf = window.conversation.transcript.content
      if cf and cf._activeFrames then
        local activeCount = #cf._activeFrames
        local freeCount = cf._freeFrames and #cf._freeFrames or 0
        local totalFrames = activeCount + freeCount
        local totalRegions = 0

        for _, f in ipairs(cf._activeFrames) do
          totalRegions = totalRegions + countRegions(f)
        end
        if cf._freeFrames then
          for _, f in ipairs(cf._freeFrames) do
            totalRegions = totalRegions + countRegions(f)
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

    -- Delta from previous snapshot
    if prevSnapshot then
      trace("  --- Delta from last /wmsg mem ---")
      local deltaKB = wmKB - prevSnapshot.wmKB
      trace("  WM memory: " .. (deltaKB >= 0 and "+" or "") .. fmt("%.1f", deltaKB) .. " KB")
      if snapshot.pools.active and prevSnapshot.pools.active then
        local dTotal = (snapshot.pools.active + snapshot.pools.free)
          - (prevSnapshot.pools.active + prevSnapshot.pools.free)
        local dRegions = snapshot.pools.regions - prevSnapshot.pools.regions
        if dTotal ~= 0 or dRegions ~= 0 then
          trace(
            "  Frames: "
              .. (dTotal >= 0 and "+" or "")
              .. dTotal
              .. "  regions: "
              .. (dRegions >= 0 and "+" or "")
              .. dRegions
          )
        end
      end
    end

    prevSnapshot = snapshot
    trace("=== End Memory Report ===")
  end

  SlashCommands.Register({
    toggle = toggle,
    memoryReport = memoryReport,
  })

  trace("initialize complete")

  runtime.icon = icon
  runtime.toggle = toggle
  runtime.refreshWindow = refreshWindow
  runtime.ensureWindow = ensureWindow

  -- Update icon badge without creating the window
  local initContacts = buildContacts()
  if icon and icon.setUnreadCount then
    icon.setUnreadCount(TableUtils.sumBy(initContacts, "unreadCount"))
  end

  return runtime
end

local function initializeRuntime()
  if Bootstrap.runtime ~= nil then
    trace("runtime already initialized")
    return Bootstrap.runtime
  end

  trace("runtime initialize")
  Bootstrap.runtime = Bootstrap.Initialize(_G, {
    accountState = _G.WhisperMessengerDB,
    characterState = _G.WhisperMessengerCharacterDB,
  })
  _G.WhisperMessengerDB = Bootstrap.runtime.accountState
  _G.WhisperMessengerCharacterDB = Bootstrap.runtime.characterState

  return Bootstrap.runtime
end

if type(_G.CreateFrame) == "function" then
  local loadFrame = _G.CreateFrame("Frame", "WhisperMessengerLoadFrame")
  local EventBridge = ns.BootstrapEventBridge
  loadFrame:RegisterEvent("ADDON_LOADED")
  loadFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
      local loadedAddonName = ...
      if loadedAddonName ~= addonName then
        return
      end

      trace("ADDON_LOADED", loadedAddonName)
      initializeRuntime()

      -- Resolve EventBridge after Initialize has run (modules now loaded)
      if not EventBridge then
        EventBridge = ns.BootstrapEventBridge
          or loadModule("WhisperMessenger.Core.Bootstrap.EventBridge", "BootstrapEventBridge")
      end
      EventBridge.RegisterLiveEvents(loadFrame)

      local Constants = loadModule("WhisperMessenger.Core.Constants", "Constants")
      for _, eventName in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
        loadFrame:RegisterEvent(eventName)
      end

      if loadFrame.UnregisterEvent then
        loadFrame:UnregisterEvent("ADDON_LOADED")
      end

      return
    end

    if event == "BN_FRIEND_LIST_SIZE_CHANGED" or event == "BN_FRIEND_INFO_CHANGED" then
      if Bootstrap.runtime then
        local BNetResolver = loadModule("WhisperMessenger.Transport.BNetResolver", "BNetResolver")
        local friendMap = BNetResolver.ScanFriendList(Bootstrap.runtime.bnetApi)

        -- Update all BNet conversations with current session bnetAccountID
        for _, conversation in pairs(Bootstrap.runtime.store.conversations) do
          if conversation.channel == "BN" and conversation.battleTag then
            local friend = friendMap[conversation.battleTag]
            if friend then
              conversation.bnetAccountID = friend.bnetAccountID
              -- Refresh metadata from live data
              local gi = friend.accountInfo and friend.accountInfo.gameAccountInfo
              if gi then
                if gi.factionName and gi.factionName ~= "" then
                  conversation.factionName = gi.factionName
                end
                if gi.className and gi.className ~= "" then
                  conversation.className = gi.className
                end
                if gi.raceName and gi.raceName ~= "" then
                  conversation.raceName = gi.raceName
                end
                if gi.characterName then
                  conversation.gameAccountName = gi.characterName .. (gi.realmName and ("-" .. gi.realmName) or "")
                end
              end
            end
          end
        end

        if Bootstrap.runtime.refreshWindow then
          Bootstrap.runtime.refreshWindow()
        end
      end
      return
    end

    if event == "PLAYER_LOGOUT" then
      if Bootstrap.runtime then
        local settings = Bootstrap.runtime.accountState and Bootstrap.runtime.accountState.settings
        if settings and settings.clearOnLogout then
          for key in pairs(Bootstrap.runtime.store.conversations) do
            Bootstrap.runtime.store.conversations[key] = nil
          end
          trace("clear on logout")
        end
      end
      return
    end

    if event == "PLAYER_ENTERING_WORLD" then
      -- Start recurring presence cache rebuild timer + first rebuild after data loads
      local PresenceCache = ns.PresenceCache
      if PresenceCache and type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
        -- First rebuild after 2s (when club data is ready), then refresh window
        _G.C_Timer.After(2, function()
          trace("PresenceCache: initial rebuild (PLAYER_ENTERING_WORLD +2s)")
          PresenceCache.Rebuild()
          if Bootstrap.runtime and Bootstrap.runtime.refreshWindow then
            Bootstrap.runtime.refreshWindow()
          end
        end)
        -- Recurring timer for subsequent rebuilds
        local function presenceTimerLoop()
          if PresenceCache.IsStale() then
            trace("PresenceCache: timer rebuild (TTL=" .. PresenceCache.GetTTL() .. "s)")
            PresenceCache.Rebuild()
          end
          _G.C_Timer.After(PresenceCache.GetTTL(), presenceTimerLoop)
        end
        _G.C_Timer.After(PresenceCache.GetTTL(), presenceTimerLoop)
      elseif Bootstrap.runtime and Bootstrap.runtime.refreshWindow then
        _G.C_Timer.After(2, function()
          Bootstrap.runtime.refreshWindow()
        end)
      end
      return
    end

    -- Guild/community presence events: debounced cache invalidation
    if
      event == "GUILD_ROSTER_UPDATE"
      or event == "CLUB_MEMBER_UPDATED"
      or event == "CLUB_MEMBER_ADDED"
      or event == "CLUB_MEMBER_REMOVED"
    then
      local PresenceCache = ns.PresenceCache
      if PresenceCache then
        PresenceCache.Invalidate()
        trace("PresenceCache: invalidated by " .. event)
        -- Debounce: rebuild after 2s to coalesce rapid events
        if not Bootstrap._presenceRebuildPending and type(_G.C_Timer) == "table" then
          Bootstrap._presenceRebuildPending = true
          _G.C_Timer.After(2, function()
            Bootstrap._presenceRebuildPending = false
            trace("PresenceCache: debounced rebuild after " .. event)
            PresenceCache.Rebuild()
          end)
        end
      end
      return
    end

    if not EventBridge then
      EventBridge = ns.BootstrapEventBridge
    end
    if EventBridge then
      EventBridge.RouteLiveEvent(
        Bootstrap.runtime,
        Bootstrap.runtime and Bootstrap.runtime.refreshWindow or nil,
        event,
        ...
      )
    end
  end)
end

return Bootstrap
