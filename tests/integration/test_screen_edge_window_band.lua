local CompactWindow = require("tests.helpers.compact_window")
local Theme = require("WhisperMessenger.UI.Theme")

-- The custom-chrome window held at a screen edge: the tab strip sits inside
-- the window in a darkened band; off the edge it hangs below as before.
local L = Theme.LAYOUT
local STRIP = 24 -- the modern tab strip
local BAND = 1 + STRIP + L.SCREEN_EDGE_TAB_BAND_PAD_BOTTOM -- flush under the 1 px divider (no overlap)

-- The darkened band the tabs sit in while docked: on the window's bottom edge.
local function band(case)
  for _, created in ipairs(case.created) do
    local p = created.points and created.points[1]
    if created:GetParent() == case.frame and p and p[1] == "BOTTOMLEFT" and p[2] == case.frame and created.mouseEnabled == false then
      return created
    end
  end
  error("no tab band")
end

local SAVED = { anchorPoint = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 50, y = 700, width = 360, height = 640 }

local function shown(side)
  local config = { showGroupChats = true, screenEdge = side }
  local case = CompactWindow.Build({ settingsConfig = config })
  case.config = config
  CompactWindow.Lay(case)
  case.frame = case.window.frame
  case.frame:Show()
  return case
end

local function savedSpot()
  local copy = {}
  for key, value in pairs(SAVED) do
    copy[key] = value
  end
  return copy
end

local function samePoint(got, want)
  if got == nil then
    return false
  end
  for i = 1, 5 do
    if got[i] ~= want[i] then
      return false
    end
  end
  return true
end

return function()
  -- test_docked_strip_sits_inside_the_window_above_the_screen_bottom
  do
    local case = shown("left")
    local strip = case.window.tabToggle.frame
    assert(strip:IsShown(), "two tabs: the strip shows")
    assert(samePoint(strip.points[1], { "BOTTOMLEFT", case.frame, "BOTTOMLEFT", 8, L.SCREEN_EDGE_TAB_BAND_PAD_BOTTOM }), "strip inside the band")
    assert(band(case):IsShown() and band(case).height == BAND, "band shown around the strip")
    local viewport = case.window.compactViewport
    assert(samePoint({ viewport:GetPoint() }, { "BOTTOMRIGHT", case.frame, "BOTTOMRIGHT", -1, 1 + BAND }), "panes end above the band")
    assert(select(4, case.frame:GetClampRectInsets()) == 0, "no clamp reach below the screen")
    local paneHeight = case.frame:GetHeight() - Theme.TOP_BAR_HEIGHT - BAND
    assert(case.window.contactsPane.height == paneHeight, "panes laid out above the strip, got " .. tostring(case.window.contactsPane.height))

    -- test_hidden_strip_lets_the_content_reach_the_bottom
    case.window.setOptionsVisible(true)
    assert(not strip:IsShown(), "settings hide the strip")
    assert(samePoint({ viewport:GetPoint() }, { "BOTTOMRIGHT", case.frame, "BOTTOMRIGHT", -1, 1 }), "content to the bottom")
    assert(not band(case):IsShown(), "no band without the strip")
    case.window.setOptionsVisible(false)
    assert(samePoint({ viewport:GetPoint() }, { "BOTTOMRIGHT", case.frame, "BOTTOMRIGHT", -1, 1 + BAND }), "strip back, band room kept again")

    -- test_off_hangs_the_strip_below_the_window_again
    case.config.screenEdge = "off"
    case.window.applyScreenEdge(savedSpot())
    assert(samePoint(strip.points[1], { "TOPLEFT", case.frame, "BOTTOMLEFT", 8, 0 }), "strip hangs again")
    assert(samePoint({ viewport:GetPoint() }, { "BOTTOMRIGHT", case.frame, "BOTTOMRIGHT", -1, 1 }), "no room kept")
    assert(not band(case):IsShown(), "no band off the edge")
    assert(select(4, case.frame:GetClampRectInsets()) == -STRIP, "clamp reaches the hanging strip again")
  end
end
