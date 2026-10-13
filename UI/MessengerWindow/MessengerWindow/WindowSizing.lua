local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local sizeValue = UIHelpers.sizeValue

local WindowSizing = {}

-- Saved window state with defaults filled in, clamped to the parent at scale.
function WindowSizing.InitialState(parent, state, scale)
  return WindowBounds.ClampState(parent, {
    anchorPoint = state.anchorPoint or "CENTER",
    relativePoint = state.relativePoint or state.anchorPoint or "CENTER",
    x = state.x or 0,
    y = state.y or 0,
    width = state.width or Theme.WINDOW_WIDTH,
    height = state.height or Theme.WINDOW_HEIGHT,
    minimized = state.minimized or false,
    contactsCollapsed = state.contactsCollapsed == true,
  }, Theme, scale)
end

-- options: frame, initialState, settingsConfig, chrome, windowGeometry,
-- scriptResult (LifecycleWiring), relayoutWindow(w, h, contactsWidth, refreshContacts)
-- Returns { setScale, relayoutCurrentSize }.
function WindowSizing.Create(options)
  local frame = options.frame
  local initialState = options.initialState
  local settingsConfig = options.settingsConfig
  local chrome = options.chrome
  local windowGeometry = options.windowGeometry
  local scriptResult = options.scriptResult
  local relayoutWindow = options.relayoutWindow

  local function setScale(nextScale)
    local currentState = windowGeometry.buildState(frame)
    local previousWidth = sizeValue(frame, "GetWidth", "width", currentState.width)
    local previousHeight = sizeValue(frame, "GetHeight", "height", currentState.height)
    currentState.width = previousWidth
    currentState.height = previousHeight
    local normalizedScale = windowGeometry.setScale(nextScale)
    settingsConfig.windowScale = normalizedScale

    local appliedState = scriptResult.withSizeChangedRelayoutSuppressed(function()
      chrome.refreshScale(normalizedScale)
      return windowGeometry.applyState(frame, currentState)
    end)
    if appliedState.width ~= previousWidth or appliedState.height ~= previousHeight then
      relayoutWindow(appliedState.width, appliedState.height, windowGeometry.getContactsWidth(), nil)
    end
    return normalizedScale
  end

  -- Re-applies the layout at the current size (theme, language and footer
  -- tab changes can all move the bottom of the contacts list).
  local function relayoutCurrentSize()
    relayoutWindow(
      sizeValue(frame, "GetWidth", "width", initialState.width),
      sizeValue(frame, "GetHeight", "height", initialState.height),
      windowGeometry.getContactsWidth(),
      false
    )
  end

  return { setScale = setScale, relayoutCurrentSize = relayoutCurrentSize }
end

ns.MessengerWindowWindowSizing = WindowSizing

return WindowSizing
