local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule
local TableUtils = loadModule("WhisperMessenger.Util.TableUtils", "TableUtils")
local clamp = TableUtils.clamp

local Metrics = ns.ScrollViewMetrics or loadModule("WhisperMessenger.UI.ScrollView.Metrics", "ScrollViewMetrics")

local Navigation = {}

function Navigation.Sync(view)
  if view == nil or view.scrollFrame == nil or view.scrollBar == nil then
    return 0
  end

  Metrics._captureLiveGeometry(view)

  local range = Metrics.GetRange(view)
  local hasOverflow = range > 0
  Metrics._applyViewportLayout(view, hasOverflow)
  range = Metrics.GetRange(view)

  local current = clamp(Metrics.GetOffset(view), 0, range)

  if view.scrollBar.SetMinMaxValues then
    view.scrollBar:SetMinMaxValues(0, range)
  end

  if view.scrollBar.SetValueStep then
    view.scrollBar:SetValueStep(view.step or 1)
  end

  view.syncingScrollBar = true
  if view.scrollBar.SetValue then
    view.scrollBar:SetValue(current)
  else
    view.scrollBar.value = current
  end
  view.syncingScrollBar = false

  if hasOverflow then
    if view.scrollBar.Show then
      view.scrollBar:Show()
    end
  elseif view.scrollBar.Hide then
    view.scrollBar:Hide()
  end

  return range
end

function Navigation.SetVerticalScroll(view, offset)
  if view == nil or view.scrollFrame == nil then
    return 0
  end

  local range = Navigation.Sync(view)
  local clamped = clamp(offset or 0, 0, range)

  view.syncingScrollFrame = true
  if view.scrollFrame.SetVerticalScroll then
    view.scrollFrame:SetVerticalScroll(clamped)
  else
    view.scrollFrame.verticalScroll = clamped
  end
  view.syncingScrollFrame = false

  view.syncingScrollBar = true
  if view.scrollBar and view.scrollBar.SetValue then
    view.scrollBar:SetValue(clamped)
  elseif view.scrollBar then
    view.scrollBar.value = clamped
  end
  view.syncingScrollBar = false

  return clamped
end

function Navigation.ScrollBy(view, delta)
  return Navigation.SetVerticalScroll(view, Metrics.GetOffset(view) + (delta or 0))
end

ns.ScrollViewNavigation = Navigation
return Navigation
