local CompactWindow = require("tests.helpers.compact_window")
local GrowRig = require("tests.helpers.grow_rig")
local Theme = require("WhisperMessenger.UI.Theme")

local L = Theme.LAYOUT
local function build(edgeSide, extra)
  extra = extra or {}
  local config = { showGroupChats = true, screenEdge = edgeSide }
  extra.settingsConfig = config
  local case = CompactWindow.Build(extra)
  case.config = config
  CompactWindow.Lay(case)
  case.frame = case.window.frame
  case.parent = case.frame:GetParent()
  return case
end

local function shown(edgeSide, extra)
  local case = build(edgeSide, extra)
  case.window.resizeGrip:Show()
  case.frame:Show()
  return case
end

local function source(case)
  for _, created in ipairs(case.created) do
    if created.growMotion then
      return created
    end
  end
  error("no edge source")
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

local function assertEdge(case, side, label)
  local points = case.frame.points
  local edge = side == "right" and "RIGHT" or "LEFT"
  local top, bottom = points[#points - 1], points[#points]
  assert(samePoint(top, { "TOP" .. edge, case.parent, "TOP" .. edge, 0, 0 }), label .. ": top point " .. tostring(top[1]))
  assert(samePoint(bottom, { "BOTTOM" .. edge, case.parent, "BOTTOM" .. edge, 0, 0 }), label .. ": bottom point " .. tostring(bottom[1]))
end

local SAVED = { anchorPoint = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 50, y = 700, width = 360, height = 640 }

local function savedSpot()
  local copy = {}
  for key, value in pairs(SAVED) do
    copy[key] = value
  end
  return copy
end

local function assertSavedSpot(case, label)
  local point, rel, relPoint, x, y = case.frame:GetPoint()
  assert(point == "TOPLEFT" and rel == case.parent and relPoint == "BOTTOMLEFT", label .. ": saved anchor")
  assert(x == 50 and y == 700, label .. ": saved spot, got " .. tostring(x) .. "," .. tostring(y))
end

return function()
  -- test_shown_window_sits_flush_left_at_full_height
  do
    assertEdge(shown("left"), "left", "left")
  end

  -- test_right_edge_sits_flush_right
  do
    assertEdge(shown("right"), "right", "right")
  end

  -- test_docked_window_cannot_move_or_resize
  do
    local case = shown("left")
    assert(not case.frame:IsMovable() and not case.window.resizeGrip:IsShown(), "pinned")
    assert(source(case):IsShown(), "the edge source is up")
  end

  -- test_drag_stop_while_docked_saves_nothing
  do
    local case = shown("left")
    case.frame.scripts.OnDragStop(case.frame)
    assert(case.saved.state == nil, "nothing saved")
    assertEdge(case, "left", "after a drag")
  end

  -- test_button_does_not_ride_and_slide_uses_the_edge_source
  do
    local case = shown("left")
    assert(case.rides == 0, "the button stays home")
    assert(select(1, case.frame:GetClampRectInsets()) == 0, "no clamp reach over the spot")
  end

  -- test_settings_widening_on_the_right_edge_stays_at_the_edge
  do
    local case = shown("right")
    case.window.setOptionsVisible(true)
    assertEdge(case, "right", "wide")
    case.window.setOptionsVisible(false)
    assertEdge(case, "right", "narrow")
  end

  -- test_scale_change_re_places_and_resizes_source
  do
    local case = shown("left")
    rawset(case.frame, "GetEffectiveScale", function()
      return 1.2
    end)
    case.frame:SetPoint("CENTER", case.parent, "CENTER", 0, 0)
    case.window.setScale(1.2)
    assertEdge(case, "left", "scaled")
    local src = source(case)
    local want = case.frame:GetWidth() * 1.2 / src:GetEffectiveScale()
    assert(math.abs(src.width - want) < 1e-9, "source width follows, got " .. tostring(src.width) .. " want " .. want)
  end

  -- test_reset_window_while_docked_stays_at_the_edge
  do
    local case = shown("left")
    case.window.applySavedState({})
    assertEdge(case, "left", "reset")
    local button = case.window.resetWindowButton
    if button and button.scripts and button.scripts.OnClick then
      button.scripts.OnClick(button)
      assertEdge(case, "left", "reset button")
    end
  end

  -- test_on_live_sends_a_riding_button_home
  do
    local case = shown("off")
    assert(case.rides == 1, "rides while floating")
    case.config.screenEdge = "left"
    case.window.applyScreenEdge(nil)
    assert(case.homes == 1, "the button goes home, got " .. case.homes)
    assertEdge(case, "left", "on live")
  end

  -- test_off_live_restores_moving_grip_and_the_saved_spot
  do
    local case = shown("left")
    case.config.screenEdge = "off"
    case.window.applyScreenEdge(savedSpot())
    assert(case.frame:IsMovable() and case.window.resizeGrip:IsShown(), "movable and resizable again")
    assertSavedSpot(case, "off live")
    assert(not source(case):IsShown(), "the edge source is gone: a close shrinks into the usual source")
  end

  -- test_applied_twice_then_off_restores_everything
  do
    local case = shown("left")
    case.window.setScale(1)
    case.frame:Hide()
    case.frame:Show()
    assertEdge(case, "left", "re-applied")
    case.config.screenEdge = "off"
    case.window.applyScreenEdge(savedSpot())
    assert(case.frame:IsMovable() and case.window.resizeGrip:IsShown(), "grip shown as before docking")
  end

  -- test_left_then_right_moves_border_and_source
  do
    local case = shown("left")
    case.config.screenEdge = "right"
    case.window.applyScreenEdge(nil)
    assertEdge(case, "right", "switched")
    local first = source(case).points[1]
    assert(first[1] == "TOPLEFT" and first[2] == case.frame and first[3] == "TOPRIGHT", "source on the outer side")
    local shade
    for _, created in ipairs(case.created) do
      if created:GetParent() == case.frame and created.width == L.SCREEN_EDGE_SHADE_WIDTH and created.mouseEnabled == false then
        shade = created
      end
    end
    assert(shade and shade.points[1][1] == "TOPRIGHT", "the shade moved to the right")
    assert(not case.frame:IsMovable(), "still pinned")
    case.config.screenEdge = "off"
    case.window.applyScreenEdge(savedSpot())
    assert(case.frame:IsMovable() and case.window.resizeGrip:IsShown(), "released")
  end

  -- test_off_live_with_no_saved_spot_centres_the_window
  do
    local case = shown("left")
    case.config.screenEdge = "off"
    case.window.applyScreenEdge(nil)
    local point, rel, relPoint, x, y = case.frame:GetPoint()
    assert(point == "TOPLEFT" and rel == case.parent and relPoint == "CENTER", "centred anchor")
    assert(x == -L.COMPACT_WINDOW_WIDTH / 2 and y == L.COMPACT_WINDOW_HEIGHT / 2, "centred")
  end

  -- test_off_when_never_docked_moves_nothing
  do
    local case = shown("off")
    local count = #case.frame.points
    local before = { case.frame:GetPoint() }
    case.window.applyScreenEdge(savedSpot())
    assert(#case.frame.points == count, "no new points")
    assert(samePoint({ case.frame:GetPoint() }, before), "same spot")
  end

  -- test_on_while_wide_goes_to_the_edge_and_back_narrow
  do
    local case = shown("off")
    local narrow = case.frame:GetWidth()
    case.window.setOptionsVisible(true)
    case.config.screenEdge = "left"
    case.window.applyScreenEdge(nil)
    assertEdge(case, "left", "wide")
    case.window.setOptionsVisible(false)
    assertEdge(case, "left", "narrow")
    assert(case.frame:GetWidth() == narrow, "compact width again")
  end

  -- test_off_while_wide_waits_for_the_narrow_window
  do
    local case = shown("left")
    case.window.setOptionsVisible(true)
    case.config.screenEdge = "off"
    case.window.applyScreenEdge(savedSpot())
    assert(select(4, case.frame:GetPoint()) ~= 50, "waits while wide")
    case.window.setOptionsVisible(false)
    assertSavedSpot(case, "after settings")
  end

  -- test_window_animation_off_means_no_slide
  do
    local case = build("left", {
      isGrowAnimationOn = function()
        return false
      end,
    })
    case.frame:Show()
    assert(not GrowRig.running(CompactWindow.Panel(case)), "no slide in")
    case.frame:Hide()
    assert(not GrowRig.running(CompactWindow.Panel(case)), "no slide out")
  end

  -- test_slide_opens_from_the_edge_source
  do
    local case = build("left")
    GrowRig.rect(source(case), -360, 100, 0, 740)
    case.frame:Show()
    local panel = CompactWindow.Panel(case)
    assert(GrowRig.running(panel), "slides")
    local point, _, relPoint, x, y = panel:GetPoint()
    assert(
      point == "TOPLEFT" and relPoint == "BOTTOMLEFT" and x == -360 and y == 740,
      "starts on the source, got " .. tostring(x) .. "," .. tostring(y)
    )
  end

  -- test_no_side_window_is_unchanged
  do
    local case = shown("off")
    assert(case.frame:IsMovable() and case.window.resizeGrip:IsShown(), "movable, resizable")
    assert(case.rides == 1, "the button rides as before")
  end
end
