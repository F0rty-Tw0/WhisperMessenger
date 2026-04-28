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
local ChatGateway = ns.ChatGateway or require("WhisperMessenger.Transport.ChatGateway")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local ToggleIcon = ns.ToggleIcon or require("WhisperMessenger.UI.ToggleIcon")
local MessengerWindow = ns.MessengerWindow or require("WhisperMessenger.UI.MessengerWindow")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local TimeFormat = ns.TimeFormat or require("WhisperMessenger.Util.TimeFormat")

local SettingsHandler = ns.BootstrapWindowRuntimeSettingsHandler or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

local ConversationSelector = ns.BootstrapWindowRuntimeConversationSelector
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ConversationSelector")
local WidgetPreview = ns.BootstrapWindowRuntimeWidgetPreview or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")
local StartConversation = ns.BootstrapWindowRuntimeStartConversation or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.StartConversation")
local GroupSendPolicy = ns.BootstrapWindowRuntimeGroupSendPolicy or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")
local WindowCallbacks = ns.BootstrapWindowRuntimeWindowCallbacks or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local IconRuntime = ns.BootstrapWindowRuntimeIconRuntime or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconRuntime")
local ToggleFlow = ns.BootstrapWindowRuntimeToggleFlow or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ToggleFlow")
local RuntimeBindings = ns.BootstrapWindowRuntimeRuntimeBindings or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.RuntimeBindings")

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

  local widgetPreview = WidgetPreview.Create({
    accountState = accountState,
    runtimeStore = runtime.store or {},
    badgeFilter = BadgeFilter,
  })

  local function buildLatestIncomingPreview(contacts)
    return widgetPreview.buildLatestIncomingPreview(contacts)
  end

  local function acknowledgeLatestWidgetPreview(contacts)
    return widgetPreview.acknowledgeLatestWidgetPreview(contacts)
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

  local groupSendPolicy = GroupSendPolicy.Create({
    runtime = runtime,
    chatGateway = ChatGateway,
  })

  runtime.getGroupSendNotice = groupSendPolicy.getNotice

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

  local startConversationFlow = StartConversation.Create({
    runtime = runtime,
    identity = Identity,
    getWindow = function()
      return window
    end,
    selectConversation = function(conversationKey)
      return selectConversation(conversationKey)
    end,
  })
  local startConversation = startConversationFlow.startConversation

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

    local windowCallbacks = WindowCallbacks.Create({
      runtime = runtime,
      characterState = characterState,
      defaultCharacterState = defaultCharacterState,
      uiParent = uiParent,
      getIcon = function()
        return icon
      end,
      tableUtils = tableUtils,
      groupSendPolicy = groupSendPolicy,
      sendHandler = sendHandler,
      refreshWindow = refreshWindow,
      selectConversation = selectConversation,
      startConversation = startConversation,
      setWindowVisible = setWindowVisible,
      trace = trace,
    })

    window = messengerWindow.Create(uiFactory, {
      contacts = contacts,
      selectedContact = selectedState.selectedContact,
      conversation = selectedState.conversation,
      status = selectedState.status,
      state = characterState.window,
      initialTabMode = characterState.contactsTabMode or "whispers",
      onTabModeChanged = windowCallbacks.onTabModeChanged,
      onSelectConversation = windowCallbacks.onSelectConversation,
      onStartConversation = windowCallbacks.onStartConversation,
      onSend = windowCallbacks.onSend,
      onPositionChanged = windowCallbacks.onPositionChanged,
      onClose = windowCallbacks.onClose,
      onResetWindowPosition = windowCallbacks.onResetWindowPosition,
      onClearAllChats = windowCallbacks.onClearAllChats,
      onPin = windowCallbacks.onPin,
      onRemove = windowCallbacks.onRemove,
      onReorder = windowCallbacks.onReorder,
      onResetIconPosition = windowCallbacks.onResetIconPosition,
      storeConfig = runtime.store.config,
      settingsConfig = settingsState,
      onSettingChanged = onSettingChanged,
    })

    if window.frame.Hide then
      window.frame:Hide()
    end

    runtime.window = window
  end

  local toggleFlow = ToggleFlow.Create({
    runtime = runtime,
    badgeFilter = BadgeFilter,
    ensureWindow = ensureWindow,
    isWindowVisible = function()
      return controller.isWindowVisible()
    end,
    setWindowVisible = setWindowVisible,
    getWindow = function()
      return window
    end,
    findLatestUnreadKey = coordinator.findLatestUnreadKey,
    selectConversation = selectConversation,
    refreshWindow = refreshWindow,
  })
  local toggle = toggleFlow.toggle

  icon = IconRuntime.Create({
    accountState = accountState,
    characterState = characterState,
    uiFactory = uiFactory,
    toggleIcon = toggleIcon,
    tableUtils = tableUtils,
    badgeFilter = BadgeFilter,
    buildContacts = buildContacts,
    buildLatestIncomingPreview = buildLatestIncomingPreview,
    acknowledgeLatestWidgetPreview = acknowledgeLatestWidgetPreview,
    refreshWindow = refreshWindow,
    onToggle = toggle,
  })

  RuntimeBindings.Apply({
    runtime = runtime,
    controller = controller,
    icon = icon,
    getWindow = function()
      return window
    end,
    getIcon = function()
      return icon
    end,
    isWindowVisible = function()
      return coordinator.isWindowVisible()
    end,
    setDiagnostics = function(nextDiagnostics)
      diagnostics = nextDiagnostics
    end,
    buildContacts = buildContacts,
    ensureWindow = ensureWindow,
    refreshWindow = refreshWindow,
    selectConversation = selectConversation,
    setWindowVisible = setWindowVisible,
    toggle = toggle,
  })

  return controller
end

ns.BootstrapWindowRuntime = WindowRuntime
return WindowRuntime
