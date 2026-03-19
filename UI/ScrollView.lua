local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = {}
local SCROLLBAR_WIDTH = 16
local SCROLLBAR_INSET = 0

local function sizeValue(target, getterName, fieldName, fallback)
  if target and type(target[getterName]) == "function" then
    local value = target[getterName](target)
    if type(value) == "number" and value > 0 then
      return value
    end
  end

  if target and type(target[fieldName]) == "number" then
    return target[fieldName]
  end

  return fallback
end

local function clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end

  if value > maximum then
    return maximum
  end

  return value
end

local function unpackValues(values)
  local unpackFn = table.unpack or _G.unpack
  if type(unpackFn) ~= "function" then
    error("unpack not available")
  end

  return unpackFn(values)
end


function ScrollView.GetRange(view)
  if view == nil or view.scrollFrame == nil then
    return 0
  end

  if type(view.scrollFrame.GetVerticalScrollRange) == "function" then
    local range = view.scrollFrame:GetVerticalScrollRange()
    if type(range) == "number" and range >= 0 then
      return range
    end
  end

  local viewportHeight = sizeValue(view.scrollFrame, "GetHeight", "height", 0)
  local contentHeight = sizeValue(view.content, "GetHeight", "height", viewportHeight)
  return math.max(contentHeight - viewportHeight, 0)
end

function ScrollView.GetOffset(view)
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

function ScrollView.Sync(view)
  if view == nil or view.scrollFrame == nil or view.scrollBar == nil then
    return 0
  end

  captureLiveGeometry(view)

  local range = ScrollView.GetRange(view)
  local hasOverflow = range > 0
  applyViewportLayout(view, hasOverflow)
  range = ScrollView.GetRange(view)

  local current = clamp(ScrollView.GetOffset(view), 0, range)

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

function ScrollView.SetVerticalScroll(view, offset)
  if view == nil or view.scrollFrame == nil then
    return 0
  end

  local range = ScrollView.Sync(view)
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

function ScrollView.ScrollBy(view, delta)
  return ScrollView.SetVerticalScroll(view, ScrollView.GetOffset(view) + (delta or 0))
end


function ScrollView.RefreshMetrics(view, contentHeight, snapToEnd)
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

  local targetOffset = snapToEnd and ScrollView.GetRange(view) or ScrollView.GetOffset(view)
  ScrollView.SetVerticalScroll(view, targetOffset)
  return nextContentHeight
end

function ScrollView.Create(factory, parent, options)
  options = options or {}

  local width = options.width or sizeValue(parent, "GetWidth", "width", 0)
  local height = options.height or sizeValue(parent, "GetHeight", "height", 0)
  local step = options.step or 24

  local scrollFrame = factory.CreateFrame("ScrollFrame", nil, parent)
  local point = options.point or { "TOPLEFT", parent, "TOPLEFT", 0, 0 }
  scrollFrame:SetPoint(unpackValues(point))
  scrollFrame:SetSize(width, height)

  local content = factory.CreateFrame("Frame", nil, scrollFrame)
  content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
  content:SetSize(width, height)
  if scrollFrame.SetScrollChild then
    scrollFrame:SetScrollChild(content)
  end

  local scrollBar = factory.CreateFrame("Slider", nil, parent)
  scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", SCROLLBAR_INSET, 0)
  scrollBar:SetSize(SCROLLBAR_WIDTH, height)
  if scrollBar.SetOrientation then
    scrollBar:SetOrientation("VERTICAL")
  end
  if scrollBar.SetMinMaxValues then
    scrollBar:SetMinMaxValues(0, 0)
  end
  if scrollBar.SetValueStep then
    scrollBar:SetValueStep(step)
  end
  if scrollBar.SetObeyStepOnDrag then
    scrollBar:SetObeyStepOnDrag(true)
  end

  local track = scrollBar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints(scrollBar)
  if track.SetColorTexture then
    track:SetColorTexture(0.1, 0.1, 0.14, 0.85)
  end
  scrollBar.track = track

  local thumb = scrollBar:CreateTexture(nil, "ARTWORK")
  thumb:SetSize(SCROLLBAR_WIDTH - 4, 24)
  if thumb.SetColorTexture then
    thumb:SetColorTexture(0.75, 0.6, 0.15, 0.95)
  end
  scrollBar.thumb = thumb
  if scrollBar.SetThumbTexture then
    scrollBar:SetThumbTexture(thumb)
  end

  if scrollBar.Hide then
    scrollBar:Hide()
  end

  if scrollBar.SetValue then
    scrollBar:SetValue(0)
  else
    scrollBar.value = 0
  end
  local view = {
    scrollFrame = scrollFrame,
    content = content,
    scrollBar = scrollBar,
    step = step,
    totalWidth = width,
    viewportHeight = height,
    syncingScrollFrame = false,
    syncingScrollBar = false,
    hasOverflow = false,
  }

  if scrollFrame.EnableMouseWheel then
    scrollFrame:EnableMouseWheel(true)
  end

  if scrollFrame.SetScript then
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
      ScrollView.ScrollBy(view, -((delta or 0) * step))
    end)
    scrollFrame:SetScript("OnVerticalScroll", function(_, offset)
      if view.syncingScrollFrame then
        return
      end

      view.syncingScrollBar = true
      if view.scrollBar and view.scrollBar.SetValue then
        view.scrollBar:SetValue(clamp(offset or 0, 0, ScrollView.GetRange(view)))
      elseif view.scrollBar then
        view.scrollBar.value = clamp(offset or 0, 0, ScrollView.GetRange(view))
      end
      view.syncingScrollBar = false
    end)
  end

  if scrollBar.SetScript then
    scrollBar:SetScript("OnValueChanged", function(_, value)
      if view.syncingScrollBar then
        return
      end

      ScrollView.SetVerticalScroll(view, value or 0)
    end)
  end

  ScrollView.Sync(view)
  return view
end

ns.ScrollView = ScrollView

return ScrollView
