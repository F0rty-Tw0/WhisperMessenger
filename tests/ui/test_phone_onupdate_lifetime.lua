local WindowGrowAnimation = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGrowAnimation")
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
  local animation = WindowGrowAnimation.Attach(frame, {
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

  -- test_hiding_the_window_mid_open_leaves_no_ticker_panel_or_hold
  do
    local ride
    local case = PhoneWindow.Build({
      getDockIcon = function()
        return ride
      end,
    })
    local fab, frame = case.fab, case.window.frame
    local parent = fab:GetParent()
    fab:SetSize(42, 42)
    fab:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 40)
    rect(frame, 100, 100, 460, 740)
    rect(fab, 80, 720, 122, 762)
    local real = IconRide.Create(fab, { theme = Theme, parent = parent })
    -- ToggleIcon's surface for the window, over the real ride.
    ride = {
      frame = fab,
      isRiding = real.isRiding,
      rideHome = real.rideHome,
      setRideStrata = real.setStrata,
      setRideHandlers = function() end,
      rideTo = function(target, onStep)
        rawset(target.region, "GetCenter", function()
          return 300, 700
        end)
        return real.rideTo(target, onStep)
      end,
    }
    parent:Show()
    fab:Show()
    frame:Show()
    assert(fab.scripts.OnUpdate ~= nil, "setup: the opening glide is running")
    runOut(fab, Theme.LAYOUT.PHONE_RIDE_SECONDS / 2)
    assert(frame:GetAlpha() < 1, "setup: the window is still being revealed")
    local panels = 0
    for _, child in ipairs(parent.children) do
      panels = panels + ((child ~= fab and child ~= frame and child:IsShown()) and 1 or 0)
    end
    assert(panels == 1, "setup: the opening panel is up, got " .. panels)
    frame:Hide()
    runOut(fab, Theme.LAYOUT.PHONE_RIDE_SECONDS * 2)
    assert(fab.scripts.OnUpdate == nil, "no ticker left on the button")
    for _, child in ipairs(parent.children) do
      assert(child == fab or child == frame or not child:IsShown(), "no panel left over the hidden window")
    end
    assert(frame:GetAlpha() == 1, "the window gets its alpha back")
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
