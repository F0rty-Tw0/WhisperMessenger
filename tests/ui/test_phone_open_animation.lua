local PhoneOpenAnimation = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneOpenAnimation")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local function rect(frame, left, bottom, right, top)
  rawset(frame, "GetLeft", function()
    return left
  end)
  rawset(frame, "GetBottom", function()
    return bottom
  end)
  rawset(frame, "GetRight", function()
    return right
  end)
  rawset(frame, "GetTop", function()
    return top
  end)
end

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", "Window", parent)
  local icon = factory.CreateFrame("Button", "Fab", parent)
  rect(frame, 100, 100, 460, 740)
  rect(icon, 80, 720, 122, 762)
  frame:SetAlpha(0.8)
  local case = { frame = frame, icon = icon, held = {}, refreshes = 0 }
  case.animation = PhoneOpenAnimation.Attach(frame, {
    factory = factory,
    parent = parent,
    theme = Theme,
    setAlphaHeld = function(held)
      case.held[#case.held + 1] = held
    end,
    refreshAlpha = function()
      case.refreshes = case.refreshes + 1
    end,
  })
  case.ghost = case.animation.ghost
  return case
end

return function()
  -- test_opening_hides_the_real_window_and_starts_the_panel_on_the_icon
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    assert(case.held[1] == true, "the alpha ticker keeps its hands off")
    assert(case.frame:GetAlpha() == 0, "the real window waits, full size and unseen")
    step(0, 0)
    assert(case.ghost:IsShown(), "the panel shows")
    assert(case.ghost.width == 42 and case.ghost.height == 42, "starts as the icon, got " .. tostring(case.ghost.width))
  end

  -- test_panel_grows_with_the_shared_clock_and_the_window_never_scales
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(0.25, 0.5)
    assert(case.ghost.width == 42 + (360 - 42) * 0.5, "half way across, got " .. tostring(case.ghost.width))
    assert(case.ghost.height == 42 + (640 - 42) * 0.5, "half way up, got " .. tostring(case.ghost.height))
    assert(case.frame:GetScale() == 1, "the real window is never scaled")
  end

  -- test_window_fades_in_late_over_the_panel
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(0.3, 0.6)
    assert(case.frame:GetAlpha() == 0, "not yet")
    step(0.9, 0.99)
    local alpha = case.frame:GetAlpha()
    assert(alpha > 0 and alpha < 0.8, "fading in, got " .. tostring(alpha))
  end

  -- test_panel_stays_solid_under_the_window_until_it_is_nearly_in
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(0.7, 0.97)
    assert(case.ghost.alpha == 1, "no see-through dip mid-crossfade, got " .. tostring(case.ghost.alpha))
  end

  -- test_finishing_hands_the_window_back
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(1, 1)
    assert(not case.ghost:IsShown(), "the panel goes")
    assert(case.held[#case.held] == false, "the ticker resumes")
    assert(case.refreshes == 1, "the window's real alpha returns")
    assert(case.frame:GetAlpha() == 0.8, "at the player's opacity, got " .. tostring(case.frame:GetAlpha()))
  end

  -- test_closing_shrinks_the_panel_back_to_the_icon
  do
    local case = build()
    local step = case.animation.beginClose(case.icon)
    step(0, 0)
    assert(case.ghost:IsShown() and case.ghost.width == 360, "starts as the window")
    step(0.5, 0.5)
    assert(case.ghost.width == 360 + (42 - 360) * 0.5, "shrinking, got " .. tostring(case.ghost.width))
    step(1, 1)
    assert(not case.ghost:IsShown(), "gone at the icon")
  end

  -- test_closing_mid_open_releases_the_window
  do
    local case = build()
    case.animation.beginOpen(case.icon)
    case.animation.beginClose(case.icon)
    assert(case.held[#case.held] == false, "a hidden window must not stay held")
  end

  -- test_finish_settles_a_running_open
  do
    local case = build()
    local step = case.animation.beginOpen(case.icon)
    step(0.2, 0.4)
    case.animation.finish()
    assert(not case.ghost:IsShown() and case.frame:GetAlpha() == 0.8, "settled")
    step(0.6, 0.9)
    assert(not case.ghost:IsShown(), "a stale step does nothing")
  end

  -- test_panel_sits_under_the_window_and_ignores_the_mouse
  do
    local case = build()
    assert(case.ghost:GetFrameLevel() < 2000, "below the raised window")
    assert(case.ghost.mouseEnabled ~= true, "clicks pass through")
  end

  -- test_stub_frames_without_edges_are_safe
  do
    local factory = FakeUI.NewFactory()
    local frame = factory.CreateFrame("Frame", "Window", nil)
    local animation = PhoneOpenAnimation.Attach(frame, {
      factory = factory,
      parent = factory.CreateFrame("Frame", "UIParent", nil),
      theme = Theme,
      setAlphaHeld = function() end,
      refreshAlpha = function() end,
    })
    local step = animation.beginOpen(factory.CreateFrame("Button", "Fab", nil))
    step(0.5, 0.5)
    step(1, 1)
  end
end
