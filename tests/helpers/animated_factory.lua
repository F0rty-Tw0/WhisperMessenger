local FakeUI = require("tests.helpers.fake_ui")

local AnimatedFactory = {}

function AnimatedFactory.makeAnimationGroup()
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
    table.insert(self.animations, anim)
    return anim
  end
  return ag
end

-- A FakeUI factory whose Frames can make animation groups. `factory.groups`
-- lists every group made, so a test can read `playing`.
function AnimatedFactory.newAnimatedFactory()
  local raw = FakeUI.NewFactory()
  local groups = {}
  local function CreateFrame(...)
    local f = raw.CreateFrame(...)
    if type(f) == "table" and f.frameType == "Frame" then
      function f:CreateAnimationGroup()
        local ag = AnimatedFactory.makeAnimationGroup()
        groups[#groups + 1] = ag
        return ag
      end
    end
    return f
  end
  return { CreateFrame = CreateFrame, groups = groups }
end

return AnimatedFactory
