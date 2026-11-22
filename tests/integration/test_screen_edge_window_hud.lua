local CompactWindow = require("tests.helpers.compact_window")
local FindUI = require("tests.helpers.find_ui")
local BevelAtlas = require("tests.helpers.bevel_atlas")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local NativeTabToggle = require("WhisperMessenger.UI.ContactsList.NativeTabToggle")

-- The Native HUD (Classic template) window held at a screen edge: content and
-- tab strip against the screen side and bottom, all back when it goes off.
local L = Theme.LAYOUT
-- The bevel (3 px), then the tabs tucked BORDER_OVERLAP up under it, then the bottom pad.
local BAND = L.SCREEN_EDGE_DIVIDER_HEIGHT - NativeTabToggle.BORDER_OVERLAP + NativeTabToggle.HEIGHT + L.SCREEN_EDGE_TAB_BAND_PAD_BOTTOM
local EDGES = L.CONTACTS_PANE_LEFT_INSET + L.CONTENT_PANE_RIGHT_INSET
local SAVED = { anchorPoint = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 50, y = 700, width = 360, height = 640 }

local function shown(side)
  local config = { showGroupChats = true, screenEdge = side }
  local case = CompactWindow.Build({ hudStyle = "classic", settingsConfig = config })
  case.config = config
  CompactWindow.Lay(case)
  case.frame = case.window.frame
  case.frame:Show()
  return case
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

local function goOff(case)
  local saved = {}
  for key, value in pairs(SAVED) do
    saved[key] = value
  end
  case.config.screenEdge = "off"
  case.window.applyScreenEdge(saved)
end

return function()
  -- test_hud_content_reaches_the_screen_side_and_bottom_and_comes_back
  BevelAtlas.With(function()
    local case = shown("right")
    local insets = Hud.ContentInsets(L)
    local area = case.frame.contentArea
    assert(
      samePoint(area.points[1], { "TOPLEFT", case.frame, "TOPLEFT", insets.left, -Hud.ContentInsets(L, "right").top }),
      "docked: inner border, below the title divider"
    )
    assert(samePoint(area.points[2], { "BOTTOMRIGHT", case.frame, "BOTTOMRIGHT", 0, 0 }), "docked: content to the screen side and bottom")
    local width = case.frame:GetWidth()
    assert(
      case.window.contactsPane.width == width - insets.left - EDGES,
      "docked: panes sized to the wider area, got " .. tostring(case.window.contactsPane.width)
    )
    -- test_hud_title_divider_sits_under_the_docked_title_row
    local divider = FindUI.find(case.frame, function(node)
      return node.atlas == "_UI-Frame-InnerTopTile"
    end)
    assert(divider.color == nil, "the bevel, no colour line over it")
    local _, _, _, _, dividerY = divider:GetPoint(1)
    assert(dividerY == -(L.SCREEN_EDGE_TITLE_ROW_HEIGHT + L.SCREEN_EDGE_TITLE_GAP), "divider under the title row, got " .. tostring(dividerY))
    goOff(case)
    assert(samePoint(area.points[2], { "BOTTOMRIGHT", case.frame, "BOTTOMRIGHT", -insets.right, insets.bottom }), "off: template insets back")
    assert(case.window.contactsPane.width == width - insets.left - insets.right - EDGES, "off: panes clear both borders again")
  end)

  -- test_hud_tabs_sit_inside_the_docked_window_and_hang_again_off
  BevelAtlas.With(function()
    local case = shown("left")
    local strip = case.window.tabToggle.frame
    local viewport = case.window.compactViewport
    assert(samePoint(strip.points[1], { "BOTTOMLEFT", case.frame, "BOTTOMLEFT", 11, L.SCREEN_EDGE_TAB_BAND_PAD_BOTTOM }), "HUD tabs inside the band")
    assert(samePoint({ viewport:GetPoint() }, { "BOTTOMRIGHT", case.frame.contentArea, "BOTTOMRIGHT", -1, 1 + BAND }), "panes end above the tabs")
    goOff(case)
    assert(samePoint(strip.points[1], { "TOPLEFT", case.frame, "BOTTOMLEFT", 11, 2 }), "HUD tabs hang again")
    assert(samePoint({ viewport:GetPoint() }, { "BOTTOMRIGHT", case.frame.contentArea, "BOTTOMRIGHT", -1, 1 }), "no room kept")
  end)

  Hud.Configure("off")
end
