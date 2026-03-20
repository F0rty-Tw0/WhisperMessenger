local addonName, ns = ...
if type(ns) ~= "table" then ns = {} end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule
local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")
local UIHelpers = loadModule("WhisperMessenger.UI.Helpers", "UIHelpers")
local sizeValue = UIHelpers.sizeValue
local TableUtils = loadModule("WhisperMessenger.Util.TableUtils", "TableUtils")
local unpackValues = TableUtils.unpackValues
local clamp = TableUtils.clamp

local Metrics = ns.ScrollViewMetrics or loadModule("WhisperMessenger.UI.ScrollView.Metrics", "ScrollViewMetrics")
local Navigation = ns.ScrollViewNavigation or loadModule("WhisperMessenger.UI.ScrollView.Navigation", "ScrollViewNavigation")

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
  if track.SetColorTexture then
    track:SetColorTexture(0, 0, 0, 0)
  end
  scrollBar.track = track

  -- Slim thumb using Theme colors and dimensions
  local thumbColors = Theme.COLORS.scrollbar
  local thumb = scrollBar:CreateTexture(nil, "ARTWORK")
  thumb:SetSize(SCROLLBAR_WIDTH, Theme.LAYOUT.SCROLLBAR_THUMB_MIN_H)
  if thumb.SetColorTexture then
    thumb:SetColorTexture(thumbColors[1], thumbColors[2], thumbColors[3], thumbColors[4])
  end
  scrollBar.thumb = thumb
  if scrollBar.SetThumbTexture then
    scrollBar:SetThumbTexture(thumb)
  end

  -- Hover behavior: widen and brighten the thumb
  if scrollBar.SetScript then
    scrollBar:SetScript("OnEnter", function()
      local hc = Theme.COLORS.scrollbar_hover
      if thumb.SetColorTexture then
        thumb:SetColorTexture(hc[1], hc[2], hc[3], hc[4])
      end
      if scrollBar.SetSize then
        scrollBar:SetSize(Theme.LAYOUT.SCROLLBAR_WIDTH_HOVER, height)
      end
      if thumb.SetWidth then
        thumb:SetWidth(Theme.LAYOUT.SCROLLBAR_WIDTH_HOVER)
      end
    end)
    scrollBar:SetScript("OnLeave", function()
      local nc = Theme.COLORS.scrollbar
      if thumb.SetColorTexture then
        thumb:SetColorTexture(nc[1], nc[2], nc[3], nc[4])
      end
      if scrollBar.SetSize then
        scrollBar:SetSize(SCROLLBAR_WIDTH, height)
      end
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
