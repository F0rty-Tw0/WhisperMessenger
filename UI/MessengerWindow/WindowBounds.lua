local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local sizeValue = UIHelpers.sizeValue

local WindowBounds = {}

local function resolveTheme(theme)
  return theme or Theme
end

local function resolveMinBounds(theme)
  local resolvedTheme = resolveTheme(theme)
  local layout = resolvedTheme.LAYOUT or {}
  local minWidth = layout.WINDOW_MIN_WIDTH or resolvedTheme.WINDOW_MIN_WIDTH or 640
  local minHeight = layout.WINDOW_MIN_HEIGHT or resolvedTheme.WINDOW_MIN_HEIGHT or 420
  return minWidth, minHeight
end

local function resolveMaxBound(parent, getterName, fieldName)
  local bound = sizeValue(parent, getterName, fieldName, 0)
  if type(bound) ~= "number" or bound <= 0 then
    return nil
  end

  return bound
end

function WindowBounds.GetResizeBounds(parent, theme)
  local resolvedTheme = resolveTheme(theme)
  local minWidth, minHeight = resolveMinBounds(resolvedTheme)
  local maxWidth = resolveMaxBound(parent, "GetWidth", "width") or resolvedTheme.WINDOW_WIDTH or minWidth
  local maxHeight = resolveMaxBound(parent, "GetHeight", "height") or resolvedTheme.WINDOW_HEIGHT or minHeight

  return minWidth, minHeight, maxWidth, maxHeight
end

function WindowBounds.ClampState(parent, state, theme)
  local resolvedTheme = resolveTheme(theme)
  local minWidth, minHeight, maxWidth, maxHeight = WindowBounds.GetResizeBounds(parent, resolvedTheme)
  local nextState = {}

  for key, value in pairs(state or {}) do
    nextState[key] = value
  end

  local width = nextState.width
  if type(width) ~= "number" then
    width = resolvedTheme.WINDOW_WIDTH
  end
  width = math.max(minWidth, width)
  if maxWidth then
    width = math.min(width, maxWidth)
  end

  local height = nextState.height
  if type(height) ~= "number" then
    height = resolvedTheme.WINDOW_HEIGHT
  end
  height = math.max(minHeight, height)
  if maxHeight then
    height = math.min(height, maxHeight)
  end

  nextState.width = width
  nextState.height = height
  return nextState
end

ns.MessengerWindowWindowBounds = WindowBounds

return WindowBounds
