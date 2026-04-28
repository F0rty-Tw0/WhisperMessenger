-- focused pulse-glow lifecycle regression
local FakeUI = require("tests.helpers.fake_ui")
local PulseGlow = require("WhisperMessenger.UI.ToggleIcon.PulseGlow")

local function makeAnimationGroup()
  local ag = {
    looping = nil,
    playing = false,
    scripts = {},
  }
  function ag:SetLooping(mode)
    self.looping = mode
  end
  function ag:SetScript(event, handler)
    self.scripts[event] = handler
  end
  function ag:Play()
    self.playing = true
    if self.scripts.OnPlay then
      self.scripts.OnPlay(self)
    end
  end
  function ag:Stop()
    self.playing = false
    if self.scripts.OnStop then
      self.scripts.OnStop(self)
    end
  end
  function ag:CreateAnimation(_kind)
    local anim = {}
    function anim:SetFromAlpha(_) end
    function anim:SetToAlpha(_) end
    function anim:SetDuration(_) end
    function anim:SetOrder(_) end
    function anim:SetScaleFrom(_, _) end
    function anim:SetScaleTo(_, _) end
    return anim
  end
  return ag
end

local function newAnimatedFactory()
  local raw = FakeUI.NewFactory()
  local function CreateFrame(...)
    local f = raw.CreateFrame(...)
    if type(f) == "table" and f.frameType == "Frame" then
      function f:CreateAnimationGroup()
        return makeAnimationGroup()
      end
    end
    return f
  end
  return { CreateFrame = CreateFrame }
end

return function()
  local factory = newAnimatedFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local frame = factory.CreateFrame("Frame", "Icon", parent)
  frame:SetSize(40, 40)

  local pulse = PulseGlow.Create(factory, frame, {
    accent = { 1, 0.5, 0, 1 },
  })

  assert(pulse.glowFrame ~= nil, "expected glowFrame exposed")
  local glow = pulse.glowFrame
  assert(glow.shown == false, "glow should start hidden")

  -- start() shows and plays animation
  pulse.start()
  assert(pulse.animation ~= nil, "expected animation group exposed")
  assert(pulse.animation.playing == true, "animation should play after start")
  assert(glow.shown == true, "OnPlay should Show glow")

  -- duplicate start() is idempotent
  pulse.start()
  assert(pulse.animation.playing == true, "second start() should keep animation playing")

  -- stop() hides and stops
  pulse.stop()
  assert(pulse.animation.playing == false, "animation should stop after stop()")
  assert(glow.shown == false, "OnStop should Hide glow")

  -- applyIconSize keeps the glow frame scaled with icon (GLOW_RATIO == 1.8)
  pulse.applyIconSize(80)
  assert(glow.width == 80 * 1.8, "glow width should follow icon size * GLOW_RATIO")
  assert(glow.height == 80 * 1.8, "glow height should follow icon size * GLOW_RATIO")
end
