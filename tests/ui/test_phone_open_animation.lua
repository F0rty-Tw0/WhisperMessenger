local PhoneOpenAnimation = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneOpenAnimation")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local function fakeGroup(api)
  local group = { anims = {} }
  function group:CreateAnimation(kind)
    local anim = { kind = kind }
    function anim:SetDuration(value)
      self.duration = value
    end
    function anim:SetOrigin(point, x, y)
      self.origin = { point, x, y }
    end
    function anim:SetSmoothing(value)
      self.smoothing = value
    end
    if api == "new" then
      function anim:SetScaleFrom(x, y)
        self.from = { x, y }
      end
      function anim:SetScaleTo(x, y)
        self.to = { x, y }
      end
    else
      function anim:SetFromScale(x, y)
        self.from = { x, y }
      end
      function anim:SetToScale(x, y)
        self.to = { x, y }
      end
    end
    self.anims[#self.anims + 1] = anim
    return anim
  end
  function group:Play()
    self.played = (self.played or 0) + 1
  end
  function group:Stop()
    self.stopped = true
  end
  return group
end

local function build(api)
  local frame = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
  local group = fakeGroup(api)
  rawset(frame, "CreateAnimationGroup", function()
    return group
  end)
  return frame, group
end

return function()
  -- test_window_grows_out_of_the_corner_by_the_button
  do
    local frame, group = build("new")
    local animation = PhoneOpenAnimation.Attach(frame, Theme)
    animation.play("BOTTOMRIGHT")
    local scale = group.anims[1]
    assert(scale.kind == "Scale", "a scale animation")
    assert(scale.origin[1] == "BOTTOMRIGHT", "origin is the button's corner")
    assert(scale.from[1] < 1 and scale.to[1] == 1, "grows to full size")
    assert(group.played == 1, "plays")
  end

  -- test_older_clients_use_the_older_scale_setters
  do
    local frame, group = build("old")
    PhoneOpenAnimation.Attach(frame, Theme).play("TOPLEFT")
    assert(group.anims[1].from ~= nil and group.anims[1].to ~= nil, "older setters used")
  end

  -- test_missing_animation_support_opens_plainly
  do
    local frame = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
    rawset(frame, "CreateAnimationGroup", false)
    PhoneOpenAnimation.Attach(frame, Theme).play("TOPLEFT")
  end
end
