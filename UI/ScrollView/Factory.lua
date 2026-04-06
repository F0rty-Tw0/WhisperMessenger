local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyColorTexture = UIHelpers.applyColorTexture
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local unpackValues = TableUtils.unpackValues
local clamp = TableUtils.clamp

local Metrics = ns.ScrollViewMetrics or require("WhisperMessenger.UI.ScrollView.Metrics")
local Navigation = ns.ScrollViewNavigation or require("WhisperMessenger.UI.ScrollView.Navigation")

local SCROLLBAR_WIDTH = Metrics.SCROLLBAR_WIDTH
local SCROLLBAR_INSET = Metrics.SCROLLBAR_INSET

local Factory = {}

function Factory.Create(factory, parent, options)
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

  -- Transparent track (slim Telegram-style bar — no dark background)
  local track = scrollBar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints(scrollBar)
  applyColorTexture(track, { 0, 0, 0, 0 })
  scrollBar.track = track

  -- Slim thumb using Theme colors and dimensions
  local thumb = scrollBar:CreateTexture(nil, "ARTWORK")
  thumb:SetSize(SCROLLBAR_WIDTH, Theme.LAYOUT.SCROLLBAR_THUMB_MIN_H)
  applyColorTexture(thumb, Theme.COLORS.scrollbar)
  scrollBar.thumb = thumb
  if scrollBar.SetThumbTexture then
    scrollBar:SetThumbTexture(thumb)
  end

  -- Hover behavior: brighten and widen the thumb only (never resize the
  -- Slider frame — resizing a Slider triggers OnValueChanged → Sync which
  -- resets the size, causing an OnEnter/OnLeave flicker loop).
  if scrollBar.SetScript then
    scrollBar:SetScript("OnEnter", function()
      applyColorTexture(thumb, Theme.COLORS.scrollbar_hover)
      if thumb.SetWidth then
        thumb:SetWidth(Theme.LAYOUT.SCROLLBAR_WIDTH_HOVER)
      end
    end)
    scrollBar:SetScript("OnLeave", function()
      applyColorTexture(thumb, Theme.COLORS.scrollbar)
      if thumb.SetWidth then
        thumb:SetWidth(SCROLLBAR_WIDTH)
      end
    end)
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
      Navigation.ScrollBy(view, -((delta or 0) * step))
    end)
    scrollFrame:SetScript("OnVerticalScroll", function(_, offset)
      if view.syncingScrollFrame then
        return
      end

      view.syncingScrollBar = true
      if view.scrollBar and view.scrollBar.SetValue then
        view.scrollBar:SetValue(clamp(offset or 0, 0, Metrics.GetRange(view)))
      elseif view.scrollBar then
        view.scrollBar.value = clamp(offset or 0, 0, Metrics.GetRange(view))
      end
      view.syncingScrollBar = false
    end)
  end

  if scrollBar.SetScript then
    scrollBar:SetScript("OnValueChanged", function(_, value)
      if view.syncingScrollBar then
        return
      end

      Navigation.SetVerticalScroll(view, value or 0)
    end)
  end

  Navigation.Sync(view)
  return view
end

ns.ScrollViewFactory = Factory
return Factory
