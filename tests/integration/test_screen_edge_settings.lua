local CompactWindow = require("tests.helpers.compact_window")
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local ScreenEdgeSetting = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ScreenEdgeSetting")

local SAVED = { anchorPoint = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 50, y = 700, width = 360, height = 640 }

-- A real compact window and the real settings handler sharing one settings table.
local function build()
  local config = { showGroupChats = true }
  local case = CompactWindow.Build({ settingsConfig = config })
  CompactWindow.Lay(case)
  case.frame = case.window.frame
  case.parent = case.frame:GetParent()
  case.config = config
  local runtime = { store = { config = {} }, window = case.window }
  case.onChange = SettingsHandler.Create({
    runtime = runtime,
    accountSettings = config,
    onScreenEdgeSetting = function(key, value)
      ScreenEdgeSetting.Apply({
        runtime = runtime,
        ensureSurface = function() end,
        updateIconSurfaces = function() end,
        readCompactSlot = function()
          return SAVED
        end,
      }, key, value)
    end,
  })
  case.frame:Show()
  return case
end

local function points(frame)
  local copy = {}
  for i, point in ipairs(frame.points) do
    copy[i] = { point[1], point[2], point[3], point[4], point[5] }
  end
  return copy
end

return function()
  -- test_changing_screen_edge_through_the_settings_handler_places_the_window_at_the_edge
  do
    local case = build()
    assert(case.frame:IsMovable(), "floats first")
    case.onChange("screenEdge", "left")
    assert(case.config.screenEdge == "left", "saved")
    assert(not case.frame:IsMovable(), "pinned at the edge")
    local last = case.frame.points[#case.frame.points]
    assert(last[1] == "BOTTOMLEFT" and last[2] == case.parent, "bottom point on the screen's left edge")
    case.onChange("screenEdge", "off")
    assert(case.frame:IsMovable(), "movable again")
    local point, _, relPoint, x, y = case.frame:GetPoint()
    assert(point == "TOPLEFT" and relPoint == "BOTTOMLEFT" and x == 50 and y == 700, "back on the saved compact spot")
  end

  -- test_reset_sends_off_and_keeps_a_floating_window
  do
    local case = build()
    local before = points(case.frame)
    case.onChange("screenEdge", "off")
    local after = points(case.frame)
    assert(#before == #after, "same number of points")
    for i = 1, #before do
      for j = 1, 5 do
        assert(before[i][j] == after[i][j], "point " .. i .. " field " .. j .. " unchanged")
      end
    end
    assert(case.frame:IsMovable(), "still movable")
  end
end
