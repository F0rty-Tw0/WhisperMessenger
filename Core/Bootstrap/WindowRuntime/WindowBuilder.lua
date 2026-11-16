local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SettingsHandler = ns.BootstrapWindowRuntimeSettingsHandler or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local DetachedPreviewRuntime = ns.BootstrapWindowRuntimeDetachedPreviewRuntime
  or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.DetachedPreviewRuntime")
local GrowSource = ns.BootstrapWindowRuntimeGrowSource or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GrowSource")
local IconMode = ns.BootstrapWindowRuntimeIconMode or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.IconMode")
local PanelPulse = ns.BootstrapWindowRuntimePanelPulse or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.PanelPulse")
local ChatCover = ns.BootstrapWindowCoordinatorChatCover or require("WhisperMessenger.Core.Bootstrap.WindowCoordinator.ChatCover")
local ContactInfo = ns.ContactInfo or require("WhisperMessenger.Model.ContactInfo")
local TimeFormat = ns.TimeFormat or require("WhisperMessenger.Util.TimeFormat")

-- Builds the messenger window on first need: the settings handler, the window
-- options, the window, its panel registry binding and its hide hook.
local WindowBuilder = {}

local function createSettingsHandler(options, settingsState)
  local surfaces = options.surfaces
  return SettingsHandler.Create({
    runtime = options.runtime,
    accountSettings = settingsState,
    theme = options.theme,
    fonts = options.fonts,
    timeFormat = TimeFormat,
    getIcon = surfaces.getIcon,
    getMinimapIcon = surfaces.getMinimap,
    buildContacts = options.buildContacts,
    applyIconMode = surfaces.applyIconMode,
    onShareWidgetPositionChanged = options.onShareWidgetPositionChanged,
    refreshSurfacesTheme = surfaces.refreshTheme,
    onDetachedSetting = function(key, value)
      DetachedPreviewRuntime.OnSettingChanged({
        accountState = options.accountState,
        ensureSurface = surfaces.ensureDetachedPreview,
        updateIconSurfaces = options.coordinator.updateIconSurfaces,
      }, key, value)
    end,
  })
end

local function createGrowSource(options, settingsState)
  local accountState = options.accountState
  return GrowSource.Create({
    resolveIconMode = function()
      return IconMode.Resolve(accountState.settings)
    end,
    getWidgetIcon = options.surfaces.getWidgetIcon,
    getMinimapIcon = options.surfaces.getMinimap,
    settings = settingsState,
  })
end

-- parts: contacts, selectedState, settingsState, onSettingChanged, compactLayout.
local function buildWindowOptions(options, parts)
  local runtime = options.runtime
  local settingsState = parts.settingsState
  local growSource = createGrowSource(options, settingsState)
  local windowOptions = {
    contacts = parts.contacts,
    selectedContact = parts.selectedState.selectedContact,
    conversation = parts.selectedState.conversation,
    status = parts.selectedState.status,
    state = options.positionSlots.read(parts.compactLayout and "compactWindow" or "window"),
    compactLayout = parts.compactLayout,
    getDockIcon = options.surfaces.getWidgetIcon,
    getGrowSource = growSource.getGrowSource,
    isGrowAnimationOn = growSource.isGrowAnimationOn,
    isIconDockOn = growSource.isIconDockOn,
    isOpenAtSavedSpot = growSource.isOpenAtSavedSpot,
    initialTabMode = options.characterState.contactsTabMode or "whispers",
    storeConfig = runtime.store.config,
    settingsConfig = settingsState,
    filters = options.accountState.filters,
    integrations = runtime.addonIntegrations and { registry = runtime.addonIntegrations, enabled = runtime.integrationAllowedAtLoad == true } or nil,
    onSettingChanged = parts.onSettingChanged,
    getContactInfoLines = function(contact)
      return ContactInfo.LinesFor(runtime, contact)
    end,
  }
  -- Every window callback passes straight through.
  for name, callback in pairs(options.windowCallbacks) do
    windowOptions[name] = callback
  end
  windowOptions.onPanelShown = PanelPulse.OnPanelShown(options.externalPreview, options.coordinator.updateIconSurfaces)
  windowOptions.onConversationUncovered = ChatCover.OnUncovered({
    runtime = runtime,
    isWindowVisible = options.isWindowVisible,
    selectConversation = options.selectConversation,
  })
  return windowOptions
end

-- The new window starts hidden; only hides after that acknowledge.
local function hideAndHook(window, options)
  if window.frame.Hide then
    window.frame:Hide()
  end
  -- ESC and the game's close-all hide the frame without setWindowVisible:
  -- acknowledge on every hide so a whisper read in the pane never pops on
  -- the widget after the window closes.
  if window.frame.HookScript then
    window.frame:HookScript("OnHide", function()
      options.acknowledgeLatestWidgetPreview(options.buildContacts())
    end)
  end
end

-- options: runtime, accountState, characterState, uiFactory, messengerWindow,
-- positionSlots, theme, fonts, surfaces, coordinator, windowCallbacks,
-- externalPreview, buildContacts, selectConversation, isWindowVisible,
-- acknowledgeLatestWidgetPreview, onShareWidgetPositionChanged.
-- onSettingsHandler(onSettingChanged) runs before the window exists and
-- onWindowCreated(window) before its panels bind, so whatever the build
-- calls back into already sees both.
function WindowBuilder.Build(options)
  local runtime = options.runtime
  local accountState = options.accountState
  local contacts = options.buildContacts()
  local selectedState = options.coordinator.buildSelectionState(contacts)
  accountState.settings = accountState.settings or {}
  local settingsState = accountState.settings

  local onSettingChanged = createSettingsHandler(options, settingsState)
  options.onSettingsHandler(onSettingChanged)

  -- Read once: changing the window style takes a reload.
  local compactLayout = settingsState.compactLayout ~= false
  runtime.compactLayoutActive = compactLayout

  local windowOptions = buildWindowOptions(options, {
    contacts = contacts,
    selectedState = selectedState,
    settingsState = settingsState,
    onSettingChanged = onSettingChanged,
    compactLayout = compactLayout,
  })
  local window = options.messengerWindow.Create(options.uiFactory, windowOptions)
  options.onWindowCreated(window)
  runtime.panelRegistry.bind(window)
  hideAndHook(window, options)

  runtime.window = window
  return window
end

ns.BootstrapWindowRuntimeWindowBuilder = WindowBuilder
return WindowBuilder
