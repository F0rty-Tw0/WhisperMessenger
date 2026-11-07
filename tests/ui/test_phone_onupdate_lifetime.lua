local PhoneOpenAnimation = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneOpenAnimation")
local IconRide = require("WhisperMessenger.UI.ToggleIcon.IconRide")
local PhoneWindow = require("tests.helpers.phone_window")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local FRAME = 1 / 60

-- Runs a frame's OnUpdate frame by frame, as the client does, until it clears.
local function runOut(frame, seconds)
  local remaining = seconds
  while remaining > 0 and frame.scripts.OnUpdate do
    frame.scripts.OnUpdate(frame, math.min(FRAME, remaining))
    remaining = remaining - FRAME
  end
end

local function buildRide()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Button", "Fab", parent)
  frame:SetSize(42, 42)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 40)
  parent:Show()
  frame:Show()
  rawset(frame, "GetCenter", function()
    local _, _, _, x, y = frame:GetPoint()
    return x, y
  end)
  local region = factory.CreateFrame("Frame", nil, parent)
  rawset(region, "GetCenter", function()
    return 300, 700
  end)
  local target = { region = region, relativePoint = "CENTER", x = 0, y = 0, scale = 2, level = 3000 }
  local ride = IconRide.Create(frame, { theme = Theme, parent = parent })
  return ride, frame, target
end

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

local function buildOpen()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", "Window", parent)
  local icon = factory.CreateFrame("Button", "Fab", parent)
  rect(frame, 100, 100, 460, 740)
  rect(icon, 80, 720, 122, 762)
  local held = {}
  local animation = PhoneOpenAnimation.Attach(frame, {
    factory = factory,
    parent = parent,
    theme = Theme,
    setAlphaHeld = function(value)
      held[#held + 1] = value
    end,
    refreshAlpha = function() end,
  })
  return animation, icon, held
end

return function()
  -- test_hiding_the_window_mid_slide_clears_the_slide_ticker
  do
    local case = PhoneWindow.Build()
    case.window.frame:Show() -- a hidden window snaps instead of sliding
    PhoneWindow.Select(case, "me::WOW::jaina")
    local viewport = case.window.phoneViewport
    assert(viewport.scripts.OnUpdate ~= nil, "setup: the slide is running")
    case.window.frame:Hide()
    assert(viewport.scripts.OnUpdate == nil, "no ticker left on a hidden window")
  end

  -- test_a_finished_ride_leaves_no_ticker
  do
    local ride, frame, target = buildRide()
    ride.rideTo(target)
    assert(frame.scripts.OnUpdate ~= nil, "setup: the glide is running")
    runOut(frame, Theme.LAYOUT.PHONE_RIDE_SECONDS * 2)
    assert(frame.scripts.OnUpdate == nil, "the clock stops after the last tick")
  end

  -- test_riding_home_mid_glide_keeps_a_single_live_ticker
  do
    local ride, frame, target = buildRide()
    ride.rideTo(target)
    runOut(frame, Theme.LAYOUT.PHONE_RIDE_SECONDS / 2)
    local first = frame.scripts.OnUpdate
    ride.rideHome()
    assert(frame.scripts.OnUpdate ~= nil and frame.scripts.OnUpdate ~= first, "the home glide replaces the first ticker")
    runOut(frame, Theme.LAYOUT.PHONE_RIDE_SECONDS * 2)
    assert(frame.scripts.OnUpdate == nil, "no ticker left after landing home")
  end

  -- test_finishing_mid_open_hides_the_panel_and_frees_the_window
  do
    local animation, icon, held = buildOpen()
    local step = animation.beginOpen(icon)
    step(0.4, 0.8)
    assert(animation.ghost:IsShown(), "setup: the panel is up")
    animation.finish()
    assert(animation.ghost:IsShown() == false, "no panel left over a hidden window")
    assert(held[#held] == false, "the alpha ticker gets the window back")
  end

  -- test_closing_mid_open_ends_with_no_panel_and_no_hold
  do
    local animation, icon, held = buildOpen()
    animation.beginOpen(icon)(0.4, 0.8)
    local close = animation.beginClose(icon)
    close(0.5, 0.5)
    close(1, 1)
    assert(animation.ghost:IsShown() == false, "the panel is gone at the icon")
    assert(held[#held] == false, "the window is not held")
  end
end
