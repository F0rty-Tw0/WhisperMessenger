local PhoneRuntime = require("tests.helpers.phone_runtime")
local Theme = require("WhisperMessenger.UI.Theme")

-- ESC hides the window directly (it is a UISpecialFrames entry) and can land
-- while the opening is still running on the button's clock.

local SECONDS = Theme.LAYOUT.PHONE_RIDE_SECONDS
local FRAME = 1 / 60
local HOME_X, HOME_Y = 700, 300
local SPOT_X, SPOT_Y = 100, 900

local function rect(frame, left, right, top, bottom)
  rawset(frame, "GetLeft", function()
    return left
  end)
  rawset(frame, "GetRight", function()
    return right
  end)
  rawset(frame, "GetTop", function()
    return top
  end)
  rawset(frame, "GetBottom", function()
    return bottom
  end)
end

-- The fake client lays nothing out, so give the regions positions.
local function placeOnScreen(runtime)
  local icon = runtime.icon
  rawset(icon.frame, "GetCenter", function()
    return HOME_X, HOME_Y
  end)
  rect(icon.frame, HOME_X - 20, HOME_X + 20, HOME_Y + 20, HOME_Y - 20)
  rect(runtime.window.frame, SPOT_X, SPOT_X + 360, SPOT_Y, SPOT_Y - 640)
  local rideTo = icon.rideTo
  icon.rideTo = function(target, onStep, instant)
    rawset(target.region, "GetCenter", function()
      return SPOT_X, SPOT_Y
    end)
    return rideTo(target, onStep, instant)
  end
end

local function tick(runtime, seconds)
  local frame = runtime.icon.frame
  local remaining = seconds
  while remaining > 0 and frame.scripts.OnUpdate do
    frame.scripts.OnUpdate(frame, math.min(FRAME, remaining))
    remaining = remaining - FRAME
  end
end

local function open(runtime)
  runtime.ensureWindow()
  placeOnScreen(runtime)
  runtime.toggle()
end

return function()
  -- test_escape_mid_opening_sends_the_button_home_and_frees_the_window
  PhoneRuntime.Run(nil, function(runtime)
    open(runtime)
    local frame = runtime.window.frame
    local icon = runtime.icon
    local point, relativeTo, relativePoint, x, y = icon.frame:GetPoint()
    tick(runtime, SECONDS / 2)
    assert(icon.frame.scripts.OnUpdate ~= nil, "still opening")
    assert(frame:GetAlpha() < 1, "still fading in")

    frame:Hide()
    assert(not icon.isRiding(), "the button heads home")
    tick(runtime, SECONDS + 0.01)

    assert(icon.frame.scripts.OnUpdate == nil, "the clock stops")
    local nextPoint, nextRelativeTo, nextRelativePoint, nextX, nextY = icon.frame:GetPoint()
    assert(nextPoint == point and nextRelativeTo == relativeTo and nextRelativePoint == relativePoint, "same anchor")
    assert(nextX == x and nextY == y, "same spot")
    assert(icon.frame:GetScale() == 1, "normal size")
  end)

  -- test_reopening_after_escape_mid_opening_opens_normally
  PhoneRuntime.Run(nil, function(runtime)
    open(runtime)
    local frame = runtime.window.frame
    tick(runtime, SECONDS / 2)
    frame:Hide()
    tick(runtime, SECONDS + 0.01)

    runtime.toggle()
    assert(frame.shown == true, "opens")
    assert(runtime.icon.isRiding(), "the button rides again")
    tick(runtime, SECONDS + 0.01)
    assert(runtime.icon.frame.scripts.OnUpdate == nil, "the opening ends")
    assert(frame:GetAlpha() > 0, "the window is not left unseen, got " .. tostring(frame:GetAlpha()))
  end)

  -- test_a_chat_reached_after_escape_mid_opening_still_works
  PhoneRuntime.Run(nil, function(runtime)
    open(runtime)
    tick(runtime, SECONDS / 2)
    runtime.window.frame:Hide()
    tick(runtime, SECONDS + 0.01)
    runtime.toggle()
    tick(runtime, SECONDS + 0.01)
    PhoneRuntime.ClickRow(runtime, PhoneRuntime.KEY)
    assert(runtime.window.contentPane:IsShown(), "chat on screen")
  end)
end
