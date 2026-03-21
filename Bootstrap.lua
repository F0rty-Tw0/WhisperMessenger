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

  local uiFactory = factory or _G
  local localProfileId = RuntimeFactory.ResolveLocalProfileId(options)
  local accountState, characterState =
    SavedState.Initialize(options.accountState, options.characterState, localProfileId)
  local defaultCharacterState = Schema.NewCharacterState()
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, localProfileId, options)

  local function buildContacts()
    return ContactsList.BuildItemsForProfile(runtime.accountState, runtime.localProfileId)
  end

  local contacts = buildContacts()
  local selectedState = ContactEnricher.BuildWindowSelectionState(runtime, contacts, buildContacts)
  trace("initialize contacts=" .. tostring(#contacts))

  local window
  local icon

  local function setWindowVisible(nextVisible)
    if window == nil or window.frame == nil then
      return
    end

    trace("set visible=" .. tostring(nextVisible))
    if nextVisible then
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

  local function refreshWindow()
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
    if window and window.refreshSelection then
      window.refreshSelection(nextState)
    end

    if icon and icon.setUnreadCount then
      icon.setUnreadCount(TableUtils.sumBy(freshContacts, "unreadCount"))
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
    local presence = type(runtime.getGuildOrCommunityPresence) == "function"
        and guid
        and runtime.getGuildOrCommunityPresence(guid)
      or nil
    local isBN = conversation.channel == "BN"

    trace("--- Contact Debug ---")
    trace("  key:          " .. tostring(conversationKey))
    trace("  channel:      " .. tostring(conversation.channel))
    trace("  guid:         " .. tostring(guid))
    trace("  faction:      " .. tostring(conversation.factionName))
    trace("  localFaction:  " .. tostring(runtime.localFaction))
    trace("  isBattleNet:  " .. tostring(isBN))
    trace("  cachedStatus: " .. (cached and cached.status or "nil"))
    trace("  canWhisper:   " .. (cached and tostring(cached.canWhisper) or "nil"))
    trace("  guildPresence: " .. tostring(presence))

    if isBN and conversation.bnetAccountID then
      local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
      local accountInfo = BNetResolver.ResolveAccountInfo(runtime.bnetApi, conversation.bnetAccountID, guid)
      if accountInfo then
        local gi = accountInfo.gameAccountInfo
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
        if ok2 and altInfo then
          local agi = altInfo.gameAccountInfo
          trace("  alt(ByGUID).isOnline: " .. tostring(altInfo.isOnline))
          trace("  alt(ByGUID).isAFK:    " .. tostring(altInfo.isAFK))
          trace("  alt(ByGUID).isDND:    " .. tostring(altInfo.isDND))
          if agi then
            trace("  alt(ByGUID).game.isOnline:  " .. tostring(agi.isOnline))
            trace("  alt(ByGUID).game.charName:  " .. tostring(agi.characterName))
            trace("  alt(ByGUID).game.faction:   " .. tostring(agi.factionName))
          end
        else
          trace("  alt(ByGUID): nil or error")
        end
      end
      -- Try alternative API: GetFriendNumGameAccounts + GetFriendGameAccountInfo
      if runtime.bnetApi and type(runtime.bnetApi.GetFriendNumGameAccounts) == "function" then
        local ok3, numAccounts = pcall(runtime.bnetApi.GetFriendNumGameAccounts, conversation.bnetAccountID)
        if ok3 and numAccounts then
          trace("  numGameAccounts: " .. tostring(numAccounts))
        end
      end
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

  local function toggle()
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
    onResetIconPosition = function()
      local nextState = TableUtils.copyState(defaultCharacterState.icon)
      characterState.icon = nextState

      if icon and icon.frame and icon.frame.SetPoint then
        local iconParent = icon.frame.parent or _G.UIParent
        icon.frame:SetPoint(nextState.anchorPoint, iconParent, nextState.relativePoint, nextState.x, nextState.y)
      end

      return nextState
    end,
  })

  if window.frame.Hide then
    window.frame:Hide()
  end

  icon = ToggleIcon.Create(uiFactory, {
    state = characterState.icon,
    onToggle = toggle,
    onPositionChanged = function(nextState)
      characterState.icon = TableUtils.copyState(nextState)
    end,
  })

  SlashCommands.Register({
    toggle = toggle,
  })

  trace("initialize complete")

  runtime.window = window
  runtime.icon = icon
  runtime.toggle = toggle
  runtime.refreshWindow = refreshWindow
  refreshWindow()

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

      if loadFrame.UnregisterEvent then
        loadFrame:UnregisterEvent("ADDON_LOADED")
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
