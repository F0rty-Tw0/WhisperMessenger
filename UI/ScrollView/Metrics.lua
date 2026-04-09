local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue

local SCROLLBAR_WIDTH = Theme.LAYOUT.SCROLLBAR_WIDTH
local SCROLLBAR_INSET = 0

local Metrics = {}

-- Export constants for other submodules
Metrics.SCROLLBAR_WIDTH = SCROLLBAR_WIDTH
Metrics.SCROLLBAR_INSET = SCROLLBAR_INSET

local function captureLiveGeometry(view)
  if view == nil or view.scrollFrame == nil then
    return 0, 0
  end

  local fallbackViewportWidth = view.hasOverflow
      and math.max((view.totalWidth or 0) - SCROLLBAR_WIDTH - SCROLLBAR_INSET, 0)
    or (view.totalWidth or 0)
  local liveViewportWidth = sizeValue(view.scrollFrame, "GetWidth", "width", fallbackViewportWidth)
  local liveViewportHeight = sizeValue(view.scrollFrame, "GetHeight", "height", view.viewportHeight or 0)

  view.totalWidth = liveViewportWidth + (view.hasOverflow and (SCROLLBAR_WIDTH + SCROLLBAR_INSET) or 0)
  view.viewportHeight = liveViewportHeight
  view.viewportWidth = liveViewportWidth
  return liveViewportWidth, liveViewportHeight
end

local function applyViewportLayout(view, hasOverflow)
  if view == nil or view.scrollFrame == nil then
    return 0
  end

  local totalWidth = view.totalWidth or 0
  local viewportHeight = view.viewportHeight or 0
  local scrollFrameWidth = hasOverflow and math.max(totalWidth - SCROLLBAR_WIDTH - SCROLLBAR_INSET, 0) or totalWidth
  local contentHeight = sizeValue(view.content, "GetHeight", "height", viewportHeight)

  if view.scrollFrame.SetSize then
    view.scrollFrame:SetSize(scrollFrameWidth, viewportHeight)
  end

  if view.content and view.content.SetSize then
    view.content:SetSize(scrollFrameWidth, contentHeight)
  end

  if view.scrollBar and view.scrollBar.SetSize then
    view.scrollBar:SetSize(SCROLLBAR_WIDTH, viewportHeight)
  end

  view.viewportWidth = scrollFrameWidth
  view.hasOverflow = hasOverflow
  return scrollFrameWidth
end

-- Export internal helpers for Factory and Navigation to use
Metrics._captureLiveGeometry = captureLiveGeometry
Metrics._applyViewportLayout = applyViewportLayout

function Metrics.GetRange(view)
  if view == nil or view.scrollFrame == nil then
    return 0
  end

  -- Always compute the range from the live content/viewport heights we
  -- control directly via SetSize. WoW's scrollFrame:GetVerticalScrollRange()
  -- lags when the content shrinks below the viewport after a previous
  -- overflow — it can return a stale positive value for one or more frames,
  -- which leaks through as a phantom scrollbar after switching from a long
  -- conversation to a short one.
  local viewportHeight = sizeValue(view.scrollFrame, "GetHeight", "height", 0)
  local contentHeight = sizeValue(view.content, "GetHeight", "height", viewportHeight)
  return math.max(contentHeight - viewportHeight, 0)
end

function Metrics.GetOffset(view)
  if view == nil or view.scrollFrame == nil then
    return 0
  end

  if type(view.scrollFrame.GetVerticalScroll) == "function" then
    local offset = view.scrollFrame:GetVerticalScroll()
    if type(offset) == "number" then
      return offset
    end
  end

  return view.scrollFrame.verticalScroll or 0
end

-- RefreshMetrics calls SetVerticalScroll which lives in Navigation.
-- To avoid a circular require, Navigation is resolved lazily at call time.
function Metrics.RefreshMetrics(view, contentHeight, snapToEnd)
  if view == nil or view.content == nil or view.scrollFrame == nil then
    return 0
  end

  captureLiveGeometry(view)

  local viewportHeight = view.viewportHeight or 0
  local nextContentHeight = math.max(viewportHeight, contentHeight or 0)
  local hasOverflow = (contentHeight or 0) > viewportHeight

  applyViewportLayout(view, hasOverflow)

  local viewportWidth = sizeValue(view.scrollFrame, "GetWidth", "width", view.viewportWidth or view.totalWidth or 0)
  if view.content.SetSize then
    view.content:SetSize(viewportWidth, nextContentHeight)
  end

  if type(view.scrollFrame.UpdateScrollChildRect) == "function" then
    view.scrollFrame:UpdateScrollChildRect()
  end

  -- Late-bind Navigation to avoid circular dependency at module load time
  local Navigation = ns.ScrollViewNavigation or require("WhisperMessenger.UI.ScrollView.Navigation")
  local targetOffset = snapToEnd and Metrics.GetRange(view) or Metrics.GetOffset(view)
  Navigation.SetVerticalScroll(view, targetOffset)
  return nextContentHeight
end

ns.ScrollViewMetrics = Metrics
return Metrics
