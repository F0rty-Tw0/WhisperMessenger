local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsList = ns.ContactsList or require("WhisperMessenger.UI.ContactsList")
local SnapshotCache = ns.ContactsListSnapshotCache or require("WhisperMessenger.UI.ContactsList.SnapshotCache")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")
local WhisperGateway = ns.WhisperGateway or require("WhisperMessenger.Transport.WhisperGateway")
local WindowCoordinator = ns.BootstrapWindowCoordinator or require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")
local RestrictedActions = ns.BootstrapRestrictedActions or require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local SendHandler = ns.BootstrapSendHandler or require("WhisperMessenger.Core.Bootstrap.SendHandler")
local LivePresenceSender = ns.BootstrapLivePresenceSender or require("WhisperMessenger.Core.Bootstrap.LivePresenceSender")
local ChatGateway = ns.ChatGateway or require("WhisperMessenger.Transport.ChatGateway")
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local ToggleIcon = ns.ToggleIcon or require("WhisperMessenger.UI.ToggleIcon")
local MessengerWindow = ns.MessengerWindow or require("WhisperMessenger.UI.MessengerWindow")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local WidgetPreview = ns.BootstrapWindowRuntimeWidgetPreview or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WidgetPreview")
local GroupSendPolicy = ns.BootstrapWindowRuntimeGroupSendPolicy or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")
local WindowActions = ns.BootstrapWindowRuntimeWindowActions or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowActions")
local Surfaces = ns.BootstrapWindowRuntimeSurfaces or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.Surfaces")
local WindowBuilder = ns.BootstrapWindowRuntimeWindowBuilder or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowBuilder")
local Flows = ns.BootstrapWindowRuntimeFlows or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.Flows")
local RuntimeBindings = ns.BootstrapWindowRuntimeRuntimeBindings or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.RuntimeBindings")
local ExternalPreview = ns.BootstrapWindowRuntimeExternalPreview or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ExternalPreview")
local WhoTriggers = ns.BootstrapWindowRuntimeWhoTriggers or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WhoTriggers")
local LiveThemeSync = ns.BootstrapWindowRuntimeLiveThemeSync or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.LiveThemeSync")
local PositionSlots = ns.BootstrapWindowRuntimePositionSlots or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PositionSlots")
local EllesmereBridge = ns.ThemeEllesmereBridge or require("WhisperMessenger.UI.Theme.EllesmereBridge")
local DetachedPreviewRuntime = ns.BootstrapWindowRuntimeDetachedPreviewRuntime
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.DetachedPreviewRuntime")

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
  local positionSlots = PositionSlots.Create({ accountState = accountState, characterState = characterState, tableUtils = tableUtils })
  local window
  local function getWindow()
    return window
  end

  -- dirtyKeys nil rebuilds all contact snapshots; a set rebuilds only those
  -- keys (incoming lines, and a Battle.net scan while the window is hidden).
  local snapshotCache = SnapshotCache.New()
  local function buildContacts(dirtyKeys)
    return contactsList.BuildItemsForProfile(runtime.accountState, runtime.localProfileId, snapshotCache, dirtyKeys)
  end

  -- The flag alone, as before: availability requests stop with the suspend.
  local function isMythicRestricted()
    return RestrictedActions.For(bootstrap).flag("mythic")
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

  -- The widget icon, minimap button, detached preview and compartment entry.
  -- Nothing is built until setHandlers and applyIconMode run below.
  local surfaces = Surfaces.Create({
    runtime = runtime,
    accountState = accountState,
    characterState = characterState,
    uiFactory = uiFactory,
    uiParent = uiParent,
    tableUtils = tableUtils,
    positionSlots = positionSlots,
    toggleIcon = toggleIcon,
    minimapIconRuntime = options.minimapIconRuntime,
    buildContacts = buildContacts,
    buildLatestIncomingPreview = buildLatestIncomingPreview,
  })

  -- Set once the window exists; live theme changes repaint through it. Until
  -- then the surfaces repaint alone.
  local liveThemeSettingChanged = nil
  LiveThemeSync.Install(options.ellesmereBridge or EllesmereBridge, theme, function()
    return liveThemeSettingChanged
  end, surfaces.refreshTheme)

  -- Assigned below; the coordinator uses it to follow a replied-to request.
  local actions

  local externalPreview = ExternalPreview.New({
    now = function()
      return runtime.now and runtime.now() or nil
    end,
    askWho = function(name)
      WhoTriggers.AskForName(runtime, name)
    end,
  })

  local coordinator = windowCoordinatorModule.Create({
    runtime = runtime,
    buildContacts = buildContacts,
    getWindow = getWindow,
    getIcon = surfaces.getWidgetIcon,
    getMinimapIcon = surfaces.getMinimapIcon,
    getLdbObject = surfaces.getLdbObject,
    getCompartment = surfaces.getCompartment,
    getDetachedPreview = surfaces.getDetachedPreview,
    previewDetached = surfaces.isPreviewDetached,
    isMythicRestricted = isMythicRestricted,
    presenceCache = presenceCache,
    livePresenceSender = LivePresenceSender,
    buildMessagePreview = buildLatestIncomingPreview,
    externalPreview = externalPreview,
    guardWhisperRefresh = options.guardWhisperRefresh,
    selectConversation = function(conversationKey)
      return actions.selectConversation(conversationKey)
    end,
  })

  runtime.onAvailabilityChanged = coordinator.scheduleAvailabilityRefresh
  runtime.scheduleIncomingRefresh = coordinator.scheduleIncomingRefresh
  runtime.scheduleWhisperRefresh = coordinator.scheduleWhisperRefresh

  local groupSendPolicy = GroupSendPolicy.Create({
    runtime = runtime,
    chatGateway = ChatGateway,
  })

  runtime.getGroupSendNotice = groupSendPolicy.getNotice

  local controller = {}

  -- Every surface that exists moves to the spot its slot now reads.
  local function onShareWidgetPositionChanged(enabled)
    positionSlots.onToggle(enabled)
    PositionSlots.Reapply(positionSlots, {
      icon = surfaces.getIcon(),
      window = window,
      compactLayoutActive = runtime.compactLayoutActive,
      minimap = surfaces.getMinimap(),
      detached = surfaces.getDetachedPreview(),
      uiParent = uiParent,
    })
  end

  -- Show and hide, refresh, select, start a conversation, the window callbacks.
  actions = WindowActions.Create({
    runtime = runtime,
    accountState = accountState,
    characterState = characterState,
    defaultCharacterState = defaultCharacterState,
    uiParent = uiParent,
    tableUtils = tableUtils,
    positionSlots = positionSlots,
    coordinator = coordinator,
    presenceCache = presenceCache,
    groupSendPolicy = groupSendPolicy,
    sendHandler = sendHandler,
    reactionHandler = options.reactionHandler,
    markConversationRead = markConversationRead,
    requestAvailability = requestAvailability,
    getIcon = surfaces.getIcon,
    getWindow = getWindow,
    buildContacts = buildContacts,
    acknowledgeLatestWidgetPreview = acknowledgeLatestWidgetPreview,
  })
  local windowCallbacks = actions.windowCallbacks
  runtime.canReact = windowCallbacks.canReact

  local function ensureWindow()
    if window then
      return
    end
    WindowBuilder.Build({
      runtime = runtime,
      accountState = accountState,
      characterState = characterState,
      uiFactory = uiFactory,
      messengerWindow = messengerWindow,
      positionSlots = positionSlots,
      theme = theme,
      fonts = fonts,
      surfaces = surfaces,
      coordinator = coordinator,
      windowCallbacks = windowCallbacks,
      externalPreview = externalPreview,
      buildContacts = buildContacts,
      selectConversation = actions.selectConversation,
      isWindowVisible = function()
        return controller.isWindowVisible()
      end,
      acknowledgeLatestWidgetPreview = acknowledgeLatestWidgetPreview,
      onShareWidgetPositionChanged = onShareWidgetPositionChanged,
      onSettingsHandler = function(onSettingChanged)
        liveThemeSettingChanged = onSettingChanged
      end,
      onWindowCreated = function(created)
        window = created
      end,
    })
  end

  local flows = Flows.Create({
    runtime = runtime,
    accountState = accountState,
    windowCallbacks = windowCallbacks,
    buildContacts = buildContacts,
    buildLatestIncomingPreview = buildLatestIncomingPreview,
    acknowledgeLatestWidgetPreview = acknowledgeLatestWidgetPreview,
    acknowledgeWidgetPreviewThrough = widgetPreview.acknowledgeWidgetPreviewThrough,
    ensureWindow = ensureWindow,
    isWindowVisible = function()
      return controller.isWindowVisible()
    end,
    setWindowVisible = actions.setWindowVisible,
    getWindow = getWindow,
    findLatestUnreadKey = coordinator.findLatestUnreadKey,
    selectConversation = actions.selectConversation,
    refreshWindow = actions.refreshWindow,
  })
  surfaces.setHandlers(flows.surfaceHandlers)

  positionSlots.seedAll()

  surfaces.applyIconMode()
  if surfaces.isPreviewDetached() then
    surfaces.ensureDetachedPreview()
    coordinator.updateIconSurfaces()
  end
  surfaces.createCompartment()

  RuntimeBindings.Apply({
    runtime = runtime,
    controller = controller,
    icon = surfaces.getIcon(),
    getWindow = getWindow,
    getIcon = surfaces.getIcon,
    isWindowVisible = function()
      return coordinator.isWindowVisible()
    end,
    buildContacts = buildContacts,
    ensureWindow = ensureWindow,
    refreshWindow = actions.refreshWindow,
    selectConversation = actions.selectConversation,
    setWindowVisible = actions.setWindowVisible,
    toggle = flows.toggle,
    toggleTargetKey = flows.openTargetKey,
    startConversation = actions.startConversation,
    externalPreview = externalPreview,
    getWidgetIcon = surfaces.getWidgetIcon,
    updateIconSurfaces = coordinator.updateIconSurfaces,
  })

  runtime.getActivePreviewSurface = function()
    return DetachedPreviewRuntime.ActiveSurface(accountState.settings, surfaces.getDetachedPreview, surfaces.getWidgetIcon)
  end

  return controller
end

ns.BootstrapWindowRuntime = WindowRuntime
return WindowRuntime
