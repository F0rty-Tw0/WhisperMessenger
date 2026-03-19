local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local function trace(...)
  if type(_G.print) == "function" then
    _G.print("[WM]", ...)
  end
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

local Bootstrap = {}
ns.Bootstrap = Bootstrap

local LIVE_EVENT_NAMES = {
  "CHAT_MSG_WHISPER",
  "CHAT_MSG_WHISPER_INFORM",
  "CHAT_MSG_AFK",
  "CHAT_MSG_DND",
  "CAN_LOCAL_WHISPER_TARGET_RESPONSE",
  "CHAT_MSG_BN_WHISPER",
  "CHAT_MSG_BN_WHISPER_INFORM",
  "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE",
}

local AVAILABILITY_STATUS_BY_CODE = {
  [0] = "CanWhisper",
  [1] = "Offline",
  [2] = "WrongFaction",
}

local function copyState(source)
  local copy = {}

  for key, value in pairs(source or {}) do
    copy[key] = value
  end

  return copy
end

local function currentTime()
  if type(_G.time) == "function" then
    return _G.time()
  end

  return 0
end

local function createRuntimeState(accountState, characterState, localProfileId, options)
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
    store = store,
    queue = Queue.New(),
    now = options.now or currentTime,
    isChatMessagingLocked = options.isChatMessagingLocked or function()
      return false
    end,
  }
end

local function normalizeAvailabilityStatus(status)
  if status == nil or type(status) == "string" then
    return status
  end

  return AVAILABILITY_STATUS_BY_CODE[status] or tostring(status)
end

local function resolveBattleNetAccountInfo(bnetApi, bnetAccountID, guid)
  if bnetApi == nil or type(bnetApi.GetAccountInfoByID) ~= "function" or bnetAccountID == nil then
    return nil
  end

  local ok, accountInfo = pcall(bnetApi.GetAccountInfoByID, bnetAccountID, guid)
  if not ok then
    return nil
  end

  return accountInfo
end

local function buildLivePayload(runtime, eventName, ...)
  if eventName == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
    local guid, status = ...
    return {
      guid = guid,
      status = normalizeAvailabilityStatus(status),
    }
  end

  if eventName == "CHAT_MSG_BN_WHISPER" or eventName == "CHAT_MSG_BN_WHISPER_INFORM" or eventName == "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE" then
    local text, playerName, _, _, _, _, _, _, _, _, lineID, guid, bnetAccountID = ...
    return {
      text = text,
      playerName = playerName,
      lineID = lineID,
      guid = guid,
      channel = "BN",
      bnetAccountID = bnetAccountID,
      accountInfo = resolveBattleNetAccountInfo(runtime and runtime.bnetApi or _G.C_BattleNet or {}, bnetAccountID, guid),
    }
  end

  local text, playerName, _, _, _, _, _, _, _, _, lineID, guid = ...
  return {
    text = text,
    playerName = playerName,
    lineID = lineID,
    guid = guid,
  }
end

local function registerLiveEvents(frame)
  for _, eventName in ipairs(LIVE_EVENT_NAMES) do
    frame:RegisterEvent(eventName)
  end
end

local function buildContacts(runtime)
  local ContactsList = loadModule("WhisperMessenger.UI.ContactsList", "ContactsList")
  return ContactsList.BuildItemsForProfile(runtime.accountState, runtime.localProfileId)
end

local function findContactByConversationKey(contacts, conversationKey)
  for _, item in ipairs(contacts or {}) do
    if item.conversationKey == conversationKey then
      return item
    end
  end

  return nil
end

local function buildConversationStatus(runtime, conversationKey, conversation)
  if conversationKey == nil then
    return nil
  end

  if runtime.sendStatusByConversation[conversationKey] ~= nil then
    return runtime.sendStatusByConversation[conversationKey]
  end

  if runtime.isChatMessagingLocked and runtime.isChatMessagingLocked() then
    local Availability = loadModule("WhisperMessenger.Transport.Availability", "Availability")
    return Availability.FromStatus("Lockdown")
  end

  if conversation and conversation.guid and runtime.availabilityByGUID[conversation.guid] then
    local availability = runtime.availabilityByGUID[conversation.guid]
    if availability.canWhisper == false then
      return availability
    end
  end

  return nil
end

local function buildWindowSelectionState(runtime, contacts)
  contacts = contacts or buildContacts(runtime)
  if runtime.activeConversationKey == nil then
    return {
      contacts = contacts,
    }
  end

  local conversationKey = runtime.activeConversationKey
  local conversation = runtime.store.conversations[conversationKey]
  local selectedContact = findContactByConversationKey(contacts, conversationKey)
  if selectedContact == nil and conversation ~= nil then
    selectedContact = {
      conversationKey = conversationKey,
      displayName = conversation.displayName or conversation.contactDisplayName or conversationKey,
      lastPreview = conversation.lastPreview or "",
      unreadCount = conversation.unreadCount or 0,
      lastActivityAt = conversation.lastActivityAt or 0,
      channel = conversation.channel or "WOW",
      guid = conversation.guid,
      bnetAccountID = conversation.bnetAccountID,
      gameAccountName = conversation.gameAccountName,
    }
  end

  return {
    contacts = contacts,
    selectedContact = selectedContact,
    conversation = conversation,
    status = buildConversationStatus(runtime, conversationKey, conversation),
  }
end

local function routeLiveEvent(eventName, ...)
  if Bootstrap.runtime == nil then
    return nil
  end

  local Router = loadModule("WhisperMessenger.Core.EventRouter", "EventRouter")
  local result = Router.HandleEvent(Bootstrap.runtime, eventName, buildLivePayload(Bootstrap.runtime, eventName, ...))
  if Bootstrap.runtime.refreshWindow then
    Bootstrap.runtime.refreshWindow()
  end

  return result
end

function Bootstrap.Initialize(factory, options)
  options = options or {}
  trace("initialize start")

  local MessengerWindow = loadModule("WhisperMessenger.UI.MessengerWindow", "MessengerWindow")
  local SavedState = loadModule("WhisperMessenger.Persistence.SavedState", "SavedState")
  local Schema = loadModule("WhisperMessenger.Persistence.Schema", "Schema")
  local SlashCommands = loadModule("WhisperMessenger.Core.SlashCommands", "SlashCommands")
  local ToggleIcon = loadModule("WhisperMessenger.UI.ToggleIcon", "ToggleIcon")
  local uiFactory = factory or _G
  local accountState, characterState = SavedState.Initialize(options.accountState, options.characterState)
  local defaultCharacterState = Schema.NewCharacterState()
  local localProfileId = options.localProfileId or "current"
  local runtime = createRuntimeState(accountState, characterState, localProfileId, options)
  local contacts = buildContacts(runtime)
  local selectedState = buildWindowSelectionState(runtime, contacts)
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
    local nextState = buildWindowSelectionState(runtime, buildContacts(runtime))
    if window and window.refreshSelection then
      window.refreshSelection(nextState)
    end

    return nextState
  end

  local function selectConversation(conversationKey)
    local Gateway = loadModule("WhisperMessenger.Transport.WhisperGateway", "WhisperGateway")
    local Store = loadModule("WhisperMessenger.Model.ConversationStore", "ConversationStore")
    local chatApi = options.chatApi or _G.C_ChatInfo or {}
    runtime.activeConversationKey = conversationKey
    characterState.activeConversationKey = conversationKey

    if conversationKey ~= nil and runtime.store.conversations[conversationKey] ~= nil then
      local conversation = runtime.store.conversations[conversationKey]
      Store.MarkRead(runtime.store, conversationKey)

      if conversation.channel == "WOW" and conversation.guid then
        Gateway.RequestAvailability(runtime.chatApi, conversation.guid)
      end
    end

    return refreshWindow()
  end

  local function toggle()
    local nextVisible = not isWindowVisible()
    setWindowVisible(nextVisible)

    if nextVisible and runtime.activeConversationKey ~= nil then
      selectConversation(runtime.activeConversationKey)
      return
    end

    refreshWindow()
  end

  runtime.isConversationOpen = function(conversationKey)
    return isWindowVisible() and runtime.activeConversationKey == conversationKey
  end

  window = MessengerWindow.Create(uiFactory, {
    title = "WhisperMessenger",
    contacts = contacts,
    selectedContact = selectedState.selectedContact,
    conversation = selectedState.conversation,
    status = selectedState.status,
    state = characterState.window,
    onSelectConversation = function(conversationKey)
      return selectConversation(conversationKey)
    end,
    onSend = function(payload)
      local Availability = loadModule("WhisperMessenger.Transport.Availability", "Availability")
      local Router = loadModule("WhisperMessenger.Core.EventRouter", "EventRouter")
      local Gateway = loadModule("WhisperMessenger.Transport.WhisperGateway", "WhisperGateway")

      runtime.sendStatusByConversation[payload.conversationKey] = nil

      if runtime.isChatMessagingLocked and runtime.isChatMessagingLocked() then
        runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Lockdown")
        refreshWindow()
        return false
      end

      local sendAvailable
      if payload.channel == "BN" then
        sendAvailable = payload.bnetAccountID ~= nil and type(runtime.bnetApi.SendWhisper) == "function"
      else
        sendAvailable = type(runtime.chatApi.SendChatMessage) == "function"
      end

      if not sendAvailable then
        runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Send unavailable")
        refreshWindow()
        return false
      end

      local pendingConversationKey = Router.RecordPendingSend(runtime, payload, payload.text)
      local callOk = false
      local sendOk = true
      if payload.channel == "BN" then
        callOk, sendOk = pcall(Gateway.SendBattleNetWhisper, runtime.bnetApi, payload.bnetAccountID, payload.text)
      else
        callOk = pcall(Gateway.SendCharacterWhisper, runtime.chatApi, payload.target, payload.text)
      end

      if not callOk or sendOk == false then
        local pending = runtime.pendingOutgoing[pendingConversationKey]
        if pending and #pending > 0 then
          table.remove(pending, #pending)
          if #pending == 0 then
            runtime.pendingOutgoing[pendingConversationKey] = nil
          end
        end

        runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Send failed")
        refreshWindow()
        return false
      end

      refreshWindow()
      return true
    end,
    onPositionChanged = function(nextState)
      characterState.window = copyState(nextState)
    end,
    onClose = function()
      setWindowVisible(false)
    end,
    onResetWindowPosition = function()
      local nextState = copyState(defaultCharacterState.window)
      characterState.window = nextState
      return nextState
    end,
    onResetIconPosition = function()
      local nextState = copyState(defaultCharacterState.icon)
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
      characterState.icon = copyState(nextState)
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
    localProfileId = "current",
  })
  _G.WhisperMessengerDB = Bootstrap.runtime.accountState
  _G.WhisperMessengerCharacterDB = Bootstrap.runtime.characterState

  return Bootstrap.runtime
end

if type(_G.CreateFrame) == "function" then
  local loadFrame = _G.CreateFrame("Frame", "WhisperMessengerLoadFrame")
  loadFrame:RegisterEvent("ADDON_LOADED")
  loadFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
      local loadedAddonName = ...
      if loadedAddonName ~= addonName then
        return
      end

      trace("ADDON_LOADED", loadedAddonName)
      initializeRuntime()
      registerLiveEvents(loadFrame)

      if loadFrame.UnregisterEvent then
        loadFrame:UnregisterEvent("ADDON_LOADED")
      end

      return
    end

    routeLiveEvent(event, ...)
  end)
end

return Bootstrap
