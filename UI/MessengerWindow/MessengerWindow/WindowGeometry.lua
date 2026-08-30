local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WindowScale = ns.MessengerWindowWindowScale or require("WhisperMessenger.UI.MessengerWindow.WindowScale")

local WindowGeometry = {}

function WindowGeometry.Create(options)
  options = options or {}

  local parent = options.parent
  local theme = options.theme
  local clampState = options.clampState
  local clampContactsWidth = options.clampContactsWidth
  local captureFramePosition = options.captureFramePosition
  local sizeValue = options.sizeValue
  local initialState = options.initialState or {}
  local currentScale = WindowScale.Normalize(options.initialScale)

  local currentContactsWidth =
    clampContactsWidth(initialState.width, options.initialContactsWidth or initialState.contactsWidth or theme.CONTACTS_WIDTH, theme)

  local function getContactsWidth()
    return currentContactsWidth
  end

  local function setContactsWidth(nextContactsWidth)
    if nextContactsWidth == nil then
      return
    end
    currentContactsWidth = nextContactsWidth
  end

  local function getScale()
    return currentScale
  end

  local function setScale(nextScale)
    currentScale = WindowScale.Normalize(nextScale)
    return currentScale
  end

  local function applyState(target, nextState)
    local clampedState = clampState(parent, nextState, theme, currentScale)
    currentContactsWidth = clampContactsWidth(clampedState.width, clampedState.contactsWidth or theme.CONTACTS_WIDTH, theme)

    target:SetSize(clampedState.width or theme.WINDOW_WIDTH, clampedState.height or theme.WINDOW_HEIGHT)
    target:ClearAllPoints()
    target:SetPoint(
      clampedState.anchorPoint or "CENTER",
      parent,
      clampedState.relativePoint or clampedState.anchorPoint or "CENTER",
      clampedState.x or 0,
      clampedState.y or 0
    )

    return clampedState
  end

  local function buildState(target)
    local pos = captureFramePosition(target)
    pos.width = sizeValue(target, "GetWidth", "width", initialState.width)
    pos.height = sizeValue(target, "GetHeight", "height", initialState.height)
    pos.contactsWidth = clampContactsWidth(pos.width, currentContactsWidth, theme)
    pos.minimized = false
    return clampState(parent, pos, theme, currentScale)
  end

  return {
    getContactsWidth = getContactsWidth,
    setContactsWidth = setContactsWidth,
    getScale = getScale,
    setScale = setScale,
    applyState = applyState,
    buildState = buildState,
  }
end

ns.MessengerWindowWindowGeometry = WindowGeometry

return WindowGeometry
