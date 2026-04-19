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

  -- Prefer the content-vs-viewport math over WoW's GetVerticalScrollRange.
  -- The native range can be stale when the scroll child was just resized
  -- (e.g., switching to a conversation with only one message while the
  -- content was previously tall), which leaves the scrollbar visible for
  -- a conversation that has no overflow. Our own SetSize on the content
  -- is authoritative here, and UpdateScrollChildRect keeps WoW in sync for
  -- scroll positioning even when we skip its range value.
  local viewportHeight = sizeValue(view.scrollFrame, "GetHeight", "height", 0)
  -- Guard: if the scrollFrame has no measured height (layout hasn't settled
  -- yet, or the frame is hidden), report no range. Without this guard every
  -- non-empty content reads as "overflow" because contentHeight > 0 > 0.
  if viewportHeight <= 0 then
    -- WoW occasionally reports 0 mid-refresh (e.g. during incoming-whisper
    -- refresh while the scrollFrame is being re-laid out). Fall back to the
    -- last captured viewport so snap-to-end still lands at the bottom
    -- instead of collapsing to offset 0 (top).
    viewportHeight = view.viewportHeight or 0
    if viewportHeight <= 0 then
      return 0
    end
  end
  local contentHeight = sizeValue(view.content, "GetHeight", "height", viewportHeight)
  local computed = math.max(contentHeight - viewportHeight, 0)
  if computed > 0 then
    return computed
  end

  if type(view.scrollFrame.GetVerticalScrollRange) == "function" then
    local range = view.scrollFrame:GetVerticalScrollRange()
    if type(range) == "number" and range > 0 then
      return range
    end
  end
  return 0
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
  -- Only treat as overflow if the viewport itself has a real height; during
  -- lifecycle moments where GetHeight returns 0 (frame not yet shown) every
  -- non-empty content would otherwise be flagged as overflowing.
  local hasOverflow = viewportHeight > 0 and (contentHeight or 0) > viewportHeight

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
