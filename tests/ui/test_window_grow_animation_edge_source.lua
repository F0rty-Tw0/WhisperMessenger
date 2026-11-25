local WindowGrowAnimation = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGrowAnimation")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")
local GrowRig = require("tests.helpers.grow_rig")

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", "Window", parent)
  local icon = factory.CreateFrame("Button", "Fab", parent)
  local source = factory.CreateFrame("Frame", "Edge", parent)
  GrowRig.rect(frame, 100, 100, 460, 740)
  GrowRig.rect(icon, 80, 720, 122, 762)
  GrowRig.rect(source, -360, 100, 0, 740)
  source:Show()
  source.growMotion = {
    whole = true,
    openSeconds = Theme.LAYOUT.SCREEN_EDGE_OPEN_SECONDS,
    closeSeconds = Theme.LAYOUT.SCREEN_EDGE_CLOSE_SECONDS,
  }
  frame:SetAlpha(0.8)
  local case = { frame = frame, icon = icon, source = source }
  case.animation = WindowGrowAnimation.Attach(frame, {
    factory = factory,
    parent = parent,
    theme = Theme,
    setAlphaHeld = function() end,
    refreshAlpha = function() end,
  })
  case.ghost = case.animation.ghost
  return case
end

return function()
  -- test_open_from_a_whole_source_starts_on_its_rectangle
  do
    local case = build()
    local step = case.animation.beginOpen(case.source)
    step(0.01, 0)
    local _, _, _, x, y = case.ghost:GetPoint()
    assert(x == -360 and y == 740 and case.ghost.width == 360 and case.ghost.height == 640)
  end

  -- test_open_from_a_whole_source_runs_for_the_open_seconds
  do
    local case = build()
    case.animation.play(case.animation.beginOpen(case.source))
    GrowRig.tick(case.ghost, 0.40)
    assert(GrowRig.running(case.ghost))
    GrowRig.tick(case.ghost, 0.05)
    assert(not GrowRig.running(case.ghost))
    assert(case.frame:GetAlpha() == 0.8, "window alpha released")
  end

  -- test_close_into_a_whole_source_ends_on_its_rectangle_after_the_close_seconds
  do
    local case = build()
    case.animation.play(case.animation.beginClose(case.source))
    GrowRig.tick(case.ghost, 0.30)
    assert(GrowRig.running(case.ghost))
    GrowRig.tick(case.ghost, 0.05)
    assert(not GrowRig.running(case.ghost) and not case.ghost:IsShown())
  end

  -- test_close_into_a_whole_source_accelerates
  do
    local case = build()
    case.animation.play(case.animation.beginClose(case.source))
    for _ = 1, 5 do
      GrowRig.tick(case.ghost, GrowRig.STEP)
    end
    local _, _, _, x = case.ghost:GetPoint()
    assert(x > 100 + (-360 - 100) * 0.5, "ease-in covers under half the way by half the time, got " .. tostring(x))
  end

  -- test_an_icon_without_growMotion_still_grows_from_its_centre_for_the_ride_seconds
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(0.01, 0)
    local _, _, _, x = case.ghost:GetPoint()
    assert(x == 101 and case.ghost.width == 1, "from the icon's centre point")
    case.animation.play(case.animation.beginOpen(case.icon))
    GrowRig.tick(case.ghost, 0.22)
    assert(GrowRig.running(case.ghost))
    GrowRig.tick(case.ghost, 0.04)
    assert(not GrowRig.running(case.ghost))
  end
end
