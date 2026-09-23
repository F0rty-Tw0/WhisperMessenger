-- focused pulse-glow lifecycle regression
local FakeUI = require("tests.helpers.fake_ui")
local PulseGlow = require("WhisperMessenger.UI.ToggleIcon.PulseGlow")

local function makeAnimationGroup()
  local ag = {
    looping = nil,
    playing = false,
    scripts = {},
    animations = {},
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
  function ag:CreateAnimation(kind)
    local anim = { kind = kind, duration = 0, endDelay = 0, order = 1 }
    function anim:SetFromAlpha(_) end
    function anim:SetToAlpha(_) end
    function anim:SetDuration(value)
      self.duration = value
    end
    function anim:SetEndDelay(value)
      self.endDelay = value
    end
    function anim:SetOrder(value)
      self.order = value
    end
    function anim:SetScaleFrom(_, _) end
    function anim:SetScaleTo(_, _) end
    table.insert(self.animations, anim)
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

  -- default (outer) glow is unchanged for other hosts (What's New button)
  assert(pulse.glowTexture.atlas == "GarrLanding-CircleGlow", "default glow should keep the outer halo atlas")
  pulse.applyIconSize(80)
  assert(glow.width == 80 * 1.8, "default glow width should follow icon size * GLOW_RATIO")
  assert(glow.height == 80 * 1.8, "default glow height should follow icon size * GLOW_RATIO")

  -- inner glow (toggle widget)
  frame:SetSize(40, 40)
  pulse = PulseGlow.Create(factory, frame, {
    accent = { 1, 0.5, 0, 1 },
    inner = true,
  })
  glow = pulse.glowFrame

  -- test_glow_is_inner_and_never_exceeds_icon: the glow sits inside the
  -- ring, so its frame matches the icon exactly (no outer halo).
  assert(glow.width == 40 and glow.height == 40, "inner glow should match icon size, got " .. tostring(glow.width))
  pulse.applyIconSize(80)
  assert(glow.width == 80, "inner glow width should follow icon size 1:1")
  assert(glow.height == 80, "inner glow height should follow icon size 1:1")

  -- test_glow_uses_inner_glow_texture_with_additive_blend
  local tex = pulse.glowTexture
  assert(
    tex.texturePath == "Interface\\AddOns\\WhisperMessenger\\Media\\inner-glow.png",
    "expected inner-glow texture, got " .. tostring(tex.texturePath)
  )
  assert(tex.atlas == nil, "outer CircleGlow atlas must no longer be used")
  assert(tex.blendMode == "ADD", "inner glow should use additive blend")

  -- test_pulse_has_no_scale_animation_so_glow_stays_inside_ring
  local cycle = { 0, 0 }
  for _, anim in ipairs(pulse.animation.animations) do
    assert(anim.kind == "Alpha", "pulse should only animate alpha, found " .. tostring(anim.kind))
    local span = anim.duration + anim.endDelay
    if span > cycle[anim.order] then
      cycle[anim.order] = span
    end
  end

  -- test_pulse_cadence_unchanged: previous cycle was 0.75s + 1.0s
  assert(math.abs(cycle[1] + cycle[2] - 1.75) < 1e-6, "pulse cycle should stay 1.75s, got " .. tostring(cycle[1] + cycle[2]))
end
