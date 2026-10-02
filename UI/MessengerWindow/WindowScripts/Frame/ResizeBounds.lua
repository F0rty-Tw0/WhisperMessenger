local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The window's live resize limits: the frame's own resize bounds (which
-- follow the screen size, window scale and collapsed contacts rail) with the
-- theme minimums as the fallback.
local ResizeBounds = {}

function ResizeBounds.IsPositiveFiniteNumber(value)
  return type(value) == "number" and value == value and value > 0 and value < math.huge
end

local isPositiveFiniteNumber = ResizeBounds.IsPositiveFiniteNumber

function ResizeBounds.Resolve(frame, frameTheme)
  local themeLayout = frameTheme.LAYOUT or {}
  local minWidth = themeLayout.WINDOW_MIN_WIDTH or frameTheme.WINDOW_MIN_WIDTH or 640
  local minHeight = themeLayout.WINDOW_MIN_HEIGHT or frameTheme.WINDOW_MIN_HEIGHT or 420
  local maxWidth, maxHeight = nil, nil

  if frame and type(frame.GetResizeBounds) == "function" then
    local nativeMinWidth, nativeMinHeight, nativeMaxWidth, nativeMaxHeight = frame:GetResizeBounds()
    if isPositiveFiniteNumber(nativeMinWidth) then
      minWidth = nativeMinWidth
    end
    if isPositiveFiniteNumber(nativeMinHeight) then
      minHeight = nativeMinHeight
    end
    if isPositiveFiniteNumber(nativeMaxWidth) and nativeMaxWidth >= minWidth then
      maxWidth = nativeMaxWidth
    end
    if isPositiveFiniteNumber(nativeMaxHeight) and nativeMaxHeight >= minHeight then
      maxHeight = nativeMaxHeight
    end
  end

  return minWidth, minHeight, maxWidth, maxHeight
end

function ResizeBounds.Clamp(frame, frameTheme, width, height)
  local minWidth, minHeight, maxWidth, maxHeight = ResizeBounds.Resolve(frame, frameTheme)
  local clampedWidth = math.max(minWidth, width or minWidth)
  local clampedHeight = math.max(minHeight, height or minHeight)
  if type(maxWidth) == "number" and maxWidth > 0 then
    clampedWidth = math.min(clampedWidth, maxWidth)
  end
  if type(maxHeight) == "number" and maxHeight > 0 then
    clampedHeight = math.min(clampedHeight, maxHeight)
  end
  return clampedWidth, clampedHeight
end

ns.MessengerWindowWindowScriptsFrameResizeBounds = ResizeBounds

return ResizeBounds
