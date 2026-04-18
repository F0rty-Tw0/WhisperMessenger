local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsList = ns.ContactsList or require("WhisperMessenger.UI.ContactsList")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")
local WhisperGateway = ns.WhisperGateway or require("WhisperMessenger.Transport.WhisperGateway")
local WindowCoordinator = ns.BootstrapWindowCoordinator or require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")
local SendHandler = ns.BootstrapSendHandler or require("WhisperMessenger.Core.Bootstrap.SendHandler")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local ToggleIcon = ns.ToggleIcon or require("WhisperMessenger.UI.ToggleIcon")
local MessengerWindow = ns.MessengerWindow or require("WhisperMessenger.UI.MessengerWindow")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local TimeFormat = ns.TimeFormat or require("WhisperMessenger.Util.TimeFormat")

local SettingsHandler = ns.BootstrapWindowRuntimeSettingsHandler
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

local ConversationSelector = ns.BootstrapWindowRuntimeConversationSelector
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ConversationSelector")

local WindowRuntime = {}

function WindowRuntime.Create(options)
  options = options or {}

  local runtime = options.runtime or {}
  local accountState = options.accountState or runtime.accountState or {}
  local characterState = options.characterState or runtime.characterState or {}
  local defaultCharacterState = options.defaultCharacterState or {}
  local uiFactory = options.uiFactory or _G
  local uiParent = options.uiParent or _G.UIParent
  local bootstrap = options.bootstrap or {}
  local trace = options.trace or function(...)
    local _ = ...
  end

  local contactsList = options.contactsList or ContactsList
  local messengerWindow = options.messengerWindow or MessengerWindow
  local toggleIcon = options.toggleIcon or ToggleIcon
  local windowCoordinatorModule = options.windowCoordinator or WindowCoordinator
  local sendHandler = options.sendHandler or SendHandler
  local tableUtils = options.tableUtils or TableUtils
  local presenceCache = options.presenceCache or PresenceCache
  local fonts = options.fonts or Fonts
  local theme = options.theme or Theme

  local markConversationRead = options.markConversationRead
    or function(store, conversationKey)
      return Store.MarkRead(store, conversationKey)
    end
  local requestAvailability = options.requestAvailability
    or function(chatApi, guid)
      return WhisperGateway.RequestAvailability(chatApi, guid)
    end

  local diagnostics = options.diagnostics or {}
  local window
  local icon

  local function buildContacts()
    return contactsList.BuildItemsForProfile(runtime.accountState, runtime.localProfileId)
  end

  local function isMythicRestricted()
    return bootstrap._inMythicContent == true
  end

  local function findLatestIncomingPreview(contacts)
    local storeConversations = runtime.store and runtime.store.conversations or {}
    local savedConversations = accountState.conversations or {}
    local latest = nil
    for _, item in ipairs(contacts or {}) do
      local conversation = savedConversations[item.conversationKey] or storeConversations[item.conversationKey]
      local sentAt = conversation and tonumber(conversation.lastIncomingAt) or nil
      local messageText = conversation and conversation.lastIncomingPreview or nil
      if sentAt and type(messageText) == "string" and messageText ~= "" then
        local senderName = conversation.lastIncomingSender or item.displayName or conversation.displayName
        if type(senderName) == "string" and senderName ~= "" then
          if latest == nil or sentAt > latest.sentAt then
            latest = {
              sentAt = sentAt,
              senderName = senderName,
              messageText = messageText,
              classTag = item.classTag or conversation.classTag,
            }
          end
        end
      end
    end

    return latest
  end

  local function buildLatestIncomingPreview(contacts)
    if accountState.settings and accountState.settings.showWidgetMessagePreview == false then
      return nil
    end

    local acknowledgedAt = tonumber(accountState.widgetPreviewAcknowledgedAt)
    local latest = findLatestIncomingPreview(contacts)
    if latest and acknowledgedAt and latest.sentAt <= acknowledgedAt then
      return nil
    end

    return latest
  end

  local function acknowledgeLatestWidgetPreview(contacts)
    local latest = findLatestIncomingPreview(contacts)
    if latest == nil then
      return
    end

    local acknowledgedAt = tonumber(accountState.widgetPreviewAcknowledgedAt) or 0
    if latest.sentAt > acknowledgedAt then
      accountState.widgetPreviewAcknowledgedAt = latest.sentAt
    end
  end

  local coordinator = windowCoordinatorModule.Create({
    runtime = runtime,
    buildContacts = buildContacts,
    getWindow = function()
      return window
    end,
    getIcon = function()
      return icon
    end,
    trace = trace,
    isMythicRestricted = isMythicRestricted,
    presenceCache = presenceCache,
    buildMessagePreview = buildLatestIncomingPreview,
  })

  runtime.onAvailabilityChanged = coordinator.scheduleAvailabilityRefresh

  local controller = {}

  local function setWindowVisible(nextVisible)
    if nextVisible then
      acknowledgeLatestWidgetPreview(buildContacts())
    end
    return coordinator.setWindowVisible(nextVisible)
  end

  local function refreshWindow()
    return coordinator.refreshWindow()
  end

  local function dismissWidgetPreview()
    acknowledgeLatestWidgetPreview(buildContacts())
    return coordinator.refreshWindow()
  end

  local conversationSelector = ConversationSelector.Create({
    runtime = runtime,
    characterState = characterState,
    markConversationRead = markConversationRead,
    presenceCache = presenceCache,
    requestAvailability = requestAvailability,
    getDiagnostics = function()
      return diagnostics
    end,
    refreshWindow = refreshWindow,
  })
  local function selectConversation(conversationKey)
    return conversationSelector.selectConversation(conversationKey)
  end

  local function normalizePlayerName(playerName)
    if type(playerName) ~= "string" then
      return nil
    end

    local trimmed = string.match(playerName, "^%s*(.-)%s*$")
    if trimmed == "" then
      return nil
    end

    return trimmed
  end

  local function findExistingConversationKeyByName(playerName)
    if type(runtime.store) ~= "table" or type(runtime.store.conversations) ~= "table" then
      return nil
    end

    local lowerName = string.lower(playerName)
    local inputBase = string.match(playerName, "^([^%-]+)")
    local lowerInputBase = inputBase and string.lower(inputBase) or nil
    local baseMatchKey = nil
    local baseMatchCount = 0

    for key, conversation in pairs(runtime.store.conversations) do
      if type(conversation) == "table" and conversation.channel == "WOW" then
        local displayName = conversation.displayName or conversation.contactDisplayName or ""
        local lowerDisplayName = string.lower(displayName)

        if lowerDisplayName == lowerName then
          return key
        end

        local baseName = string.match(displayName, "^([^%-]+)")
        if baseName and string.lower(baseName) == lowerName then
          baseMatchCount = baseMatchCount + 1
          baseMatchKey = key
        elseif lowerInputBase and lowerDisplayName == lowerInputBase then
          baseMatchCount = baseMatchCount + 1
          baseMatchKey = key
        end
      end
    end

    if baseMatchCount == 1 then
      return baseMatchKey
    end

    return nil
  end

  local function ensureWhisperConversation(conversationKey, displayName)
    runtime.store = runtime.store or {}
    runtime.store.conversations = runtime.store.conversations or {}

    if runtime.store.conversations[conversationKey] ~= nil then
      return
    end

    local now = 0
    if type(runtime.now) == "function" then
      now = runtime.now()
    elseif type(_G.time) == "function" then
      now = _G.time()
    end

    runtime.store.conversations[conversationKey] = {
      displayName = displayName,
      channel = "WOW",
      messages = {},
      unreadCount = 0,
      lastActivityAt = now,
      conversationKey = conversationKey,
    }
  end

  local function focusComposerInput()
    if window and window.composer and window.composer.input and window.composer.input.SetFocus then
      window.composer.input:SetFocus()
    end
  end

  local function startConversation(playerName)
    local normalizedName = normalizePlayerName(playerName)
    if normalizedName == nil then
      return false
    end

    local conversationKey = findExistingConversationKeyByName(normalizedName)
    if conversationKey == nil then
      local identity = Identity.FromWhisper(normalizedName, nil, {})
      if identity.canonicalName == "" then
        return false
      end

      conversationKey = Identity.BuildConversationKey(runtime.localProfileId, identity.contactKey)
      if type(conversationKey) ~= "string" or conversationKey == "" then
        return false
      end

      ensureWhisperConversation(conversationKey, normalizedName)
    end

    selectConversation(conversationKey)
    focusComposerInput()
    return true
  end

  local function ensureWindow()
    if window then
      return
    end

    local contacts = buildContacts()
    local selectedState = coordinator.buildSelectionState(contacts)
    local settingsState = (function()
      accountState.settings = accountState.settings or {}
      return accountState.settings
    end)()
    local onSettingChanged = SettingsHandler.Create({
      runtime = runtime,
      accountSettings = settingsState,
      theme = theme,
      fonts = fonts,
      timeFormat = TimeFormat,
      trace = trace,
      getIcon = function()
        return icon
      end,
      buildContacts = buildContacts,
      tableUtils = tableUtils,
    })

    window = messengerWindow.Create(uiFactory, {
      contacts = contacts,
      selectedContact = selectedState.selectedContact,
      conversation = selectedState.conversation,
      status = selectedState.status,
      state = characterState.window,
      onSelectConversation = function(conversationKey)
        return selectConversation(conversationKey)
      end,
      onStartConversation = function(playerName)
        return startConversation(playerName)
      end,
      onSend = function(payload)
        return sendHandler.HandleSend(runtime, payload, refreshWindow)
      end,
      onPositionChanged = function(nextState)
        characterState.window = tableUtils.copyState(nextState)
      end,
      onClose = function()
        setWindowVisible(false)
      end,
      onResetWindowPosition = function()
        local nextState = tableUtils.copyState(defaultCharacterState.window)
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
        local key = item.conversationKey
        trace("onPin", "key=" .. tostring(key), "wasPinned=" .. tostring(item.pinned))
        if Store.IsPinned(runtime.store, key) then
          Store.Unpin(runtime.store, key)
          if runtime.store.conversations[key] == nil and runtime.activeConversationKey == key then
            runtime.activeConversationKey = nil
            characterState.activeConversationKey = nil
          end
        else
          Store.Pin(runtime.store, key)
        end
        refreshWindow()
      end,
      onRemove = function(item)
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
        trace("onReorder", "keys=" .. tostring(#orders or 0))
        for key, order in pairs(orders) do
          Store.SetSortOrder(runtime.store, key, order)
          trace("  sortOrder", "key=" .. tostring(key), "order=" .. tostring(order))
        end
        refreshWindow()
      end,
      onResetIconPosition = function()
        local nextState = tableUtils.copyState(defaultCharacterState.icon)
        characterState.icon = nextState

        if icon and icon.frame and icon.frame.SetPoint then
          local iconParent = icon.frame.parent or uiParent
          icon.frame:SetPoint(nextState.anchorPoint, iconParent, nextState.relativePoint, nextState.x, nextState.y)
        end

        return nextState
      end,
      storeConfig = runtime.store.config,
      settingsConfig = settingsState,
      onSettingChanged = onSettingChanged,
    })

    if window.frame.Hide then
      window.frame:Hide()
    end

    runtime.window = window
  end

  local function toggle()
    ensureWindow()
    local nextVisible = not controller.isWindowVisible()
    setWindowVisible(nextVisible)

    if nextVisible then
      local unreadKey = coordinator.findLatestUnreadKey()
      local targetKey = unreadKey or runtime.activeConversationKey
      if targetKey ~= nil then
        selectConversation(targetKey)
        return
      end
    end

    refreshWindow()
  end

  local function setComposerText(text)
    if window and window.composer and window.composer.input and window.composer.input.SetText then
      window.composer.input:SetText(text or "")
    end
  end

  function controller.getWindow()
    return window
  end

  function controller.getIcon()
    return icon
  end

  function controller.isWindowVisible()
    return coordinator.isWindowVisible()
  end

  function controller.setDiagnostics(nextDiagnostics)
    diagnostics = nextDiagnostics or {}
  end

  controller.buildContacts = buildContacts
  controller.ensureWindow = ensureWindow
  controller.refreshWindow = refreshWindow
  controller.selectConversation = selectConversation
  controller.setWindowVisible = setWindowVisible
  controller.setComposerText = setComposerText
  controller.toggle = toggle

  runtime.isConversationOpen = function(conversationKey)
    return controller.isWindowVisible() and runtime.activeConversationKey == conversationKey
  end

  icon = toggleIcon.Create(uiFactory, {
    state = characterState.icon,
    iconSize = accountState.settings.iconSize,
    onToggle = toggle,
    onPositionChanged = function(nextState)
      characterState.icon = tableUtils.copyState(nextState)
    end,
    getShowUnreadBadge = function()
      return accountState.settings.showUnreadBadge ~= false
    end,
    getBadgePulse = function()
      return accountState.settings.badgePulse ~= false
    end,
    getIconDesaturated = function()
      return accountState.settings.iconDesaturated ~= false
    end,
    getPreviewAutoDismissSeconds = function()
      local value = accountState.settings.widgetPreviewAutoDismissSeconds
      if value == nil then
        return 30
      end
      return tonumber(value) or 0
    end,
    getPreviewPosition = function()
      local value = accountState.settings.widgetPreviewPosition
      if type(value) ~= "string" or value == "" then
        return "right"
      end
      return value
    end,
    onDismissPreview = dismissWidgetPreview,
  })

  runtime.icon = icon
  runtime.toggle = toggle
  runtime.refreshWindow = refreshWindow
  runtime.ensureWindow = ensureWindow
  runtime.setWindowVisible = setWindowVisible
  runtime.setComposerText = setComposerText

  local initContacts = buildContacts()
  if icon and icon.setUnreadCount then
    icon.setUnreadCount(tableUtils.sumBy(initContacts, "unreadCount"))
  end
  if icon and icon.setIncomingPreview then
    local preview = buildLatestIncomingPreview(initContacts)
    icon.setIncomingPreview(
      preview and preview.senderName or nil,
      preview and preview.messageText or nil,
      preview and preview.classTag or nil
    )
  end

  return controller
end

ns.BootstrapWindowRuntime = WindowRuntime
return WindowRuntime
