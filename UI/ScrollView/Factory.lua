local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue
local applyColorTexture = UIHelpers.applyColorTexture
local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
local unpackValues = TableUtils.unpackValues
local clamp = TableUtils.clamp

local Metrics = ns.ScrollViewMetrics or require("WhisperMessenger.UI.ScrollView.Metrics")
local Navigation = ns.ScrollViewNavigation or require("WhisperMessenger.UI.ScrollView.Navigation")
local RetailSkin = ns.ScrollViewRetailSkin or require("WhisperMessenger.UI.ScrollView.RetailSkin")

local SCROLLBAR_WIDTH = Metrics.SCROLLBAR_WIDTH
local SCROLLBAR_INSET = Metrics.SCROLLBAR_INSET

-- Native WoW HUD: the gold knob from UIPanelScrollBarTemplate, scaled down
-- whole from its 18x24 template size (the file pads the knob with empty
-- space, hence the crop) and floating with no trough, so it takes little room.
local HUD_KNOB = "Interface\\Buttons\\UI-ScrollBar-Knob"
local HUD_KNOB_ASPECT = 24 / 18
local HUD_KNOB_COORDS = { 0.20, 0.80, 0.125, 0.875 }
local CLEAR = { 0, 0, 0, 0 }

-- Dresses the slider in Blizzard scroll art; returns the theme repaint, a
-- no-op since the knob keeps its own colours.
local function skinHud(track, thumb)
  local width = Theme.LAYOUT.SCROLLBAR_WIDTH_HUD
  thumb:SetSize(width, width * HUD_KNOB_ASPECT)
  NativeArt.SetOpaque(thumb, HUD_KNOB)
  if thumb.SetTexCoord then
    thumb:SetTexCoord(unpackValues(HUD_KNOB_COORDS))
  end
  applyColorTexture(track, CLEAR)
  return function() end
end

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
  -- SetScrollChild alone does not force WoW to clip descendant frames to the
  -- scrollFrame's rect. Contact-row Buttons live inside the scroll child, and
  -- a partial last row at the bottom paints on top of the pane border and
  -- window chrome without this call.
  if scrollFrame.SetClipsChildren then
    scrollFrame:SetClipsChildren(true)
  end

  local content = factory.CreateFrame("Frame", nil, scrollFrame)
  content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
  content:SetSize(width, height)
  if scrollFrame.SetScrollChild then
    scrollFrame:SetScrollChild(content)
  end

  local hud = Hud.IsOn()
  local scrollBar = factory.CreateFrame("Slider", nil, parent)
  scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", SCROLLBAR_INSET, 0)
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
  scrollBar.track = track

  -- Slim thumb using Theme colors and dimensions
  local thumb = scrollBar:CreateTexture(nil, "ARTWORK")
  thumb:SetSize(SCROLLBAR_WIDTH, Theme.LAYOUT.SCROLLBAR_THUMB_MIN_H)

  -- Repainted by refreshSkin() on live preset switches without rebuilding
  -- the scrollview.
  local function paintThumb()
    applyColorTexture(thumb, Theme.COLORS.scrollbar)
  end
  local scrollbarWidth = SCROLLBAR_WIDTH
  local rightGutter = 0
  local refreshSkin = paintThumb
  if Hud.IsRetail() and RetailSkin.Supported(track) then
    scrollbarWidth = RetailSkin.Width()
    rightGutter = math.min(options.rightGutter or 0, Theme.LAYOUT.SCROLLBAR_RETAIL_GUTTER)
    refreshSkin = RetailSkin.Apply(scrollBar, track, thumb, scrollbarWidth)
  elseif hud then
    scrollbarWidth = Theme.LAYOUT.SCROLLBAR_WIDTH_HUD
    -- The knob sits flush with the parent's edge, in the caller's gutter.
    rightGutter = options.rightGutter or 0
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", SCROLLBAR_INSET + math.max(0, rightGutter - scrollbarWidth), 0)
    refreshSkin = skinHud(track, thumb)
  else
    -- Transparent track (slim Telegram-style bar — no dark background)
    applyColorTexture(track, { 0, 0, 0, 0 })
    paintThumb()
  end
  scrollBar:SetSize(scrollbarWidth, height)

  scrollBar.thumb = thumb
  if scrollBar.SetThumbTexture then
    scrollBar:SetThumbTexture(thumb)
  end

  -- Hover behavior: brighten and widen the thumb only (never resize the
  -- Slider frame — resizing a Slider triggers OnValueChanged → Sync which
  -- resets the size, causing an OnEnter/OnLeave flicker loop). The HUD
  -- knob stays as it is; the Retail skin swaps its own hover art.
  if scrollBar.SetScript and not hud then
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
    scrollbarWidth = scrollbarWidth,
    rightGutter = rightGutter,
    refreshSkin = refreshSkin,
  }

  if scrollFrame.EnableMouseWheel then
    scrollFrame:EnableMouseWheel(true)
  end

  if scrollFrame.SetScript then
    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
      Navigation.ScrollBy(view, -((delta or 0) * view.step))
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
