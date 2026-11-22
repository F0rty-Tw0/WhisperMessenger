local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local CompactDock = ns.MessengerWindowCompactDock or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.CompactDock")
local ScreenEdgeBorder = ns.MessengerWindowChromeBuilderScreenEdgeBorder
  or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ScreenEdgeBorder")
local BlizzardChrome = ns.MessengerWindowChromeBuilderBlizzard or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.BlizzardChrome")
local ScreenEdgeTabBand = ns.MessengerWindowChromeBuilderScreenEdgeTabBand
  or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.ScreenEdgeTabBand")
local CompactViewport = ns.MessengerWindowLayoutCompactViewport or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.CompactViewport")

-- The compact window held against the left or right screen edge: full height,
-- not movable, not resizable, no position saved, sliding out of the edge.
-- Hooks() returns the calls MessengerWindow makes while building, which do
-- nothing until Attach fills them in.
local EdgeWiring = {}

-- The side, only for the compact window.
function EdgeWiring.Side(settings)
  if settings.compactLayout == false then
    return nil
  end
  local side = settings.screenEdge
  if side == "left" or side == "right" then
    return side
  end
  return nil
end

function EdgeWiring.Hooks()
  return {
    side = function()
      return nil
    end,
    apply = function()
      return false
    end,
    applyLive = function(_savedState) end,
    source = nil,
  }
end

-- A window at the edge saves no position.
function EdgeWiring.WrapPosition(edge, onPositionChanged)
  return function(nextState)
    if edge.side() == nil then
      onPositionChanged(nextState)
    end
  end
end

-- DockWiring's window options: at the edge the window grows from the edge
-- source, no button rides it and it opens where it is placed.
function EdgeWiring.DockOptions(edge, windowOptions)
  local function own(name, fallback)
    local read = windowOptions[name]
    if read then
      return read()
    end
    return fallback
  end
  return setmetatable({
    getGrowSource = function()
      if edge.side() then
        return edge.source
      end
      return own("getGrowSource", nil)
    end,
    isIconDockOn = function()
      if edge.side() then
        return false
      end
      return own("isIconDockOn", true)
    end,
    isOpenAtSavedSpot = function()
      if edge.side() then
        return true
      end
      return own("isOpenAtSavedSpot", true)
    end,
  }, { __index = windowOptions })
end

-- options: factory, frame, chrome, layout, tabToggle, settingsConfig,
-- compactLayout, scriptResult (its applyWindowSize is wrapped: call before
-- anyone captures it).
function EdgeWiring.Attach(edge, options)
  local frame = options.frame
  local grip = options.chrome.resizeGrip
  local tabToggle = options.tabToggle
  local scriptResult = options.scriptResult
  local L = Theme.LAYOUT
  -- The Native HUD window is the one with a template content area.
  local hud = frame.contentArea ~= nil
  local border = ScreenEdgeBorder.Create(options.factory, frame, options.chrome.windowEdges, {
    hud = hud,
    titleHeight = hud and (L.SCREEN_EDGE_TITLE_ROW_HEIGHT + L.SCREEN_EDGE_TITLE_GAP) or (L.TOP_BAR_HEIGHT + 1),
  })
  local band = ScreenEdgeTabBand.Create(options.factory, frame, { hud = hud })

  local source = options.factory.CreateFrame("Frame", nil, frame:GetParent() or _G.UIParent)
  source:EnableMouse(false)
  -- Shown only while at the edge: a close after the edge went off must not slide into it.
  source:Hide()
  source.growMotion = { whole = true, openSeconds = L.SCREEN_EDGE_OPEN_SECONDS, closeSeconds = L.SCREEN_EDGE_CLOSE_SECONDS }
  edge.source = source

  local placedSide = nil
  local gripWasShown = false
  local layout = options.layout

  -- At the edge the tab strip sits inside the window in its own band; the
  -- panes end above the band while the strip shows.
  local function stripReserve(side)
    if side and tabToggle and tabToggle.frame:IsShown() then
      return band.show(tabToggle.frame:GetHeight(), tabToggle.overlap)
    end
    band.hide()
    return 0
  end

  -- The HUD content area, the panes' bottom and their sizes follow the hidden
  -- borders and the strip. State is recorded before the relayout, which may
  -- come back here.
  local function placeContent(side)
    local reserve = stripReserve(side)
    if layout.screenEdge == side and (layout.bottomReserve or 0) == reserve then
      return
    end
    layout.screenEdge = side
    layout.bottomReserve = reserve
    if frame.contentArea then
      BlizzardChrome.PlaceContentArea(frame.contentArea, frame, L, side)
    end
    if layout.compactViewport then
      CompactViewport.SetBottomReserve(layout.compactViewport, reserve, Theme)
    end
    if edge.relayout then
      edge.relayout()
    end
  end

  local function setStripInside(inside)
    if tabToggle and tabToggle.setInside then
      tabToggle.setInside(inside, L.SCREEN_EDGE_TAB_BAND_PAD_BOTTOM)
    end
  end

  edge.side = function()
    return options.compactLayout and EdgeWiring.Side(options.settingsConfig) or nil
  end

  -- The source is the window's size, just past the screen edge.
  local function anchorSource(side)
    local outer, inner = "LEFT", "RIGHT"
    if side == "right" then
      outer, inner = "RIGHT", "LEFT"
    end
    source:ClearAllPoints()
    source:SetPoint("TOP" .. inner, frame, "TOP" .. outer, 0, 0)
    source:SetPoint("BOTTOM" .. inner, frame, "BOTTOM" .. outer, 0, 0)
    source:SetWidth(frame:GetWidth() * frame:GetEffectiveScale() / source:GetEffectiveScale())
  end

  -- Runs on every show, resize, re-dock and move. True only when it just took
  -- the window off the edge; the caller then restores the position.
  edge.apply = function()
    local side = edge.side()
    if side == nil then
      if placedSide == nil then
        return false
      end
      placedSide = nil
      frame:SetMovable(true)
      if grip and gripWasShown then
        grip:Show()
      end
      border.apply(nil)
      setStripInside(false)
      placeContent(nil)
      source:Hide()
      return true
    end
    if placedSide == nil then
      gripWasShown = grip ~= nil and grip:IsShown()
      frame:SetMovable(false)
      -- A side picked from a dropdown menu was a click outside, so the window is MEDIUM by now.
      -- HIGH is the ceiling: the addon's popovers, dialogs and the colour picker are DIALOG.
      if frame:GetFrameStrata() ~= "HIGH" then
        frame:SetFrameStrata("HIGH")
      end
    elseif placedSide ~= side then
      border.apply(nil)
    end
    placedSide = side
    if grip then
      grip:Hide()
    end
    CompactDock.PlaceAtEdge(frame, side)
    border.apply(side)
    setStripInside(true)
    placeContent(side)
    anchorSource(side)
    source:Show()
    return false
  end

  frame:HookScript("OnShow", function()
    edge.apply()
  end)
  -- TabLayout reads toggle.setShown at call time, so this runs on every change.
  if tabToggle then
    local setShown = tabToggle.setShown
    tabToggle.setShown = function(shown)
      setShown(shown)
      if placedSide then
        placeContent(placedSide)
      end
    end
  end
  local applyWindowSize = scriptResult.applyWindowSize
  scriptResult.applyWindowSize = function(...)
    applyWindowSize(...)
    edge.apply()
  end
end

-- dock: DockWiring hooks after DockWiring.Attach. applySavedState(state) puts
-- the window back where it was saved ({} = centred). relayout() lays the panes
-- out again at the current size.
function EdgeWiring.Bind(edge, dock, applySavedState, relayout)
  edge.relayout = relayout
  local dockNow, onWindowMoved = dock.dock, dock.onWindowMoved
  dock.dock = function()
    edge.apply()
    dockNow()
  end
  dock.onWindowMoved = function()
    edge.apply()
    onWindowMoved()
  end
  edge.applyLive = function(savedState)
    if edge.apply() then
      applySavedState(savedState or {})
    end
    dock.dock()
  end
end

ns.MessengerWindowEdgeWiring = EdgeWiring

return EdgeWiring
