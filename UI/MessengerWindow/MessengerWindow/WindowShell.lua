local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local WindowScale = ns.MessengerWindowWindowScale or require("WhisperMessenger.UI.MessengerWindow.WindowScale")
local ChromeBuilder = ns.MessengerWindowChromeBuilder or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = ns.MessengerWindowLayoutBuilder or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local SettingsRuntime = ns.MessengerWindowSettingsRuntime or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsRuntime")
local WindowGeometry = ns.MessengerWindowWindowGeometry or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGeometry")
local WindowSizing = ns.MessengerWindowWindowSizing or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowSizing")
local WindowSurface = ns.MessengerWindowWindowSurface or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowSurface")
local PhoneDock = ns.MessengerWindowPhoneDock or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDock")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local StyledTextInputPopup = ns.StyledTextInputPopup or require("WhisperMessenger.UI.Shared.StyledTextInputPopup")
local sizeValue = UIHelpers.sizeValue
local captureFramePosition = UIHelpers.captureFramePosition

local WindowShell = {}

-- The window's static structure: geometry, chrome, panes and settings panels.
function WindowShell.Build(factory, options)
  local parent = options.parent or _G.UIParent
  local settingsConfig = options.settingsConfig or {}
  local initialScale = WindowScale.Normalize(settingsConfig.windowScale)
  settingsConfig.windowScale = initialScale
  local state = options.state or {}
  local phoneLayout = options.phoneLayout == true
  local initialState = WindowSizing.InitialState(parent, state, initialScale, phoneLayout)
  local windowGeometry = WindowGeometry.Create({
    parent = parent,
    theme = Theme,
    clampState = WindowBounds.ClampState,
    clampContactsWidth = LayoutBuilder.ClampContactsWidth,
    captureFramePosition = phoneLayout and PhoneDock.CapturePosition or captureFramePosition,
    sizeValue = sizeValue,
    initialState = initialState,
    initialContactsWidth = state.contactsWidth,
    initialScale = initialScale,
  })
  local currentContactsWidth = windowGeometry.getContactsWidth()

  -- Build chrome (outer frame, buttons, etc.). useNativeChrome flips the
  -- frame to the HUD style's Blizzard template (see ChromeBuilder), set at
  -- boot, so a change applies after /reload.
  local nativeChrome = Hud.IsOn()
  StyledTextInputPopup.nativeChrome = nativeChrome
  local chrome = ChromeBuilder.Build(factory, parent, initialState, {
    title = options.title,
    useNativeChrome = nativeChrome,
    windowScale = initialScale,
    onMarkAllRead = options.onMarkAllRead,
    phoneLayout = phoneLayout,
  })
  local frame = chrome.frame

  -- Build layout (panes)
  local layout = LayoutBuilder.Build(factory, frame, initialState, { contactsWidth = currentContactsWidth, phoneLayout = phoneLayout })
  currentContactsWidth = layout.expandedContactsWidth or layout.contactsWidth or currentContactsWidth
  windowGeometry.setContactsWidth(currentContactsWidth)
  local optionsScrollContent = layout.optionsScrollView and layout.optionsScrollView.content or layout.optionsContentPane
  -- Construct each settings panel when its tab is selected.
  local settingsResult, onPanelCreated = WindowSurface.CollectSettings()
  local settingsRuntime = SettingsRuntime.Create(factory, {
    parent = optionsScrollContent,
    settingsConfig = settingsConfig,
    storeConfig = options.storeConfig or {},
    filters = options.filters,
    onSettingChanged = options.onSettingChanged,
    theme = Theme,
    chrome = chrome,
    layout = layout,
    onPanelCreated = onPanelCreated,
  })

  return {
    parent = parent,
    settingsConfig = settingsConfig,
    phoneLayout = phoneLayout,
    initialState = initialState,
    windowGeometry = windowGeometry,
    contactsWidth = currentContactsWidth,
    nativeChrome = nativeChrome,
    chrome = chrome,
    frame = frame,
    layout = layout,
    settingsRuntime = settingsRuntime,
    settingsResult = settingsResult,
  }
end

ns.MessengerWindowWindowShell = WindowShell

return WindowShell
