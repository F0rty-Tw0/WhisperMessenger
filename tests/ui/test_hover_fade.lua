local FakeUI = require("tests.helpers.fake_ui")
local HoverFade = require("WhisperMessenger.UI.Helpers.HoverFade")

-- Minimal AnimationGroup stub: records the Alpha animation config and lets
-- the test finish playback explicitly.
local function installAnimationStub(region)
  local stub = { created = 0, plays = 0 }
  function region:CreateAnimationGroup()
    stub.created = stub.created + 1
    local group = { scripts = {}, playing = false }
    function group:CreateAnimation(kind)
      assert(kind == "Alpha", "expected an Alpha animation")
      local anim = {}
      function anim:SetDuration(d)
        stub.duration = d
      end
      function anim:SetFromAlpha(a)
        stub.from = a
      end
      function anim:SetToAlpha(a)
        stub.to = a
      end
      return anim
    end
    function group:SetToFinalAlpha(v)
      stub.finalAlpha = v
    end
    function group:SetScript(name, fn)
      self.scripts[name] = fn
    end
    function group:Play()
      stub.plays = stub.plays + 1
      self.playing = true
    end
    function group:Stop()
      self.playing = false
    end
    function group:IsPlaying()
      return self.playing
    end
    stub.finish = function()
      group.playing = false
      group.scripts.OnFinished(group)
    end
    return group
  end
  return stub
end

return function()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)

  -- test_fallback_without_animation_support_is_instant
  do
    local region = frame:CreateTexture(nil, "ARTWORK")
    region:Hide()
    local fade = HoverFade.Attach(region)
    fade.set(true)
    assert(region:IsShown() == true, "fallback: shows instantly")
    fade.set(false)
    assert(region:IsShown() == false, "fallback: hides instantly")
  end

  -- test_fade_in_uses_short_alpha_animation
  do
    local region = frame:CreateTexture(nil, "ARTWORK")
    region:Hide()
    local stub = installAnimationStub(region)
    local fade = HoverFade.Attach(region)
    assert(stub.created == 1, "animation group created once at attach")
    assert(stub.duration == 0.1, "fade duration should be 0.1s, got " .. tostring(stub.duration))
    fade.set(true)
    assert(region:IsShown() == true, "fade-in: region shown before animating")
    assert(stub.from == 0 and stub.to == 1, "fade-in: animates 0 -> 1")
    fade.set(true)
    assert(stub.plays == 1, "repeated set(true) while fading in must not restart the animation")
    stub.finish()
    assert(region:GetAlpha() == 1 and region:IsShown() == true, "fade-in: settles fully visible")
    fade.set(true)
    assert(stub.plays == 1, "set(true) when already visible is a no-op")
  end

  -- test_fade_out_hides_when_finished
  do
    local region = frame:CreateTexture(nil, "ARTWORK")
    region:Hide()
    local stub = installAnimationStub(region)
    local fade = HoverFade.Attach(region)
    fade.set(true)
    stub.finish()
    fade.set(false)
    assert(stub.from == 1 and stub.to == 0, "fade-out: animates 1 -> 0")
    assert(region:IsShown() == true, "fade-out: stays shown while animating")
    stub.finish()
    assert(region:IsShown() == false, "fade-out: hidden once finished")
    assert(stub.created == 1, "no new animation groups per hover")
  end

  -- Hover handlers repaint (paintVertex) and then call set(). A repaint while
  -- a fade is still running must not raise the shared alpha channel to the
  -- colour's full alpha: the next fade would start from a solid disc.
  local FAINT = { 1, 1, 1, 0.05 }

  -- test_repaint_mid_fade_in_then_leave_starts_fade_out_faint
  do
    local region = frame:CreateTexture(nil, "ARTWORK")
    region:Hide()
    local stub = installAnimationStub(region)
    local fade = HoverFade.Attach(region)
    fade.paintVertex(FAINT)
    fade.set(true)
    fade.paintVertex(FAINT) -- quick mouse-out: OnLeave repaints mid fade-in
    fade.set(false)
    assert(stub.from <= FAINT[4], "fade-out must start at most at the faint peak, got " .. tostring(stub.from))
  end

  -- test_repaint_mid_fade_out_then_enter_starts_fade_in_faint
  do
    local region = frame:CreateTexture(nil, "ARTWORK")
    region:Hide()
    local stub = installAnimationStub(region)
    local fade = HoverFade.Attach(region)
    fade.paintVertex(FAINT)
    fade.set(true)
    stub.finish()
    fade.paintVertex(FAINT)
    fade.set(false)
    fade.paintVertex(FAINT) -- quick mouse-in: OnEnter repaints mid fade-out
    fade.set(true)
    assert(stub.from <= FAINT[4], "fade-in must start at most at the faint peak, got " .. tostring(stub.from))
  end

  -- test_repaint_while_hidden_keeps_region_transparent
  do
    local region = frame:CreateTexture(nil, "ARTWORK")
    region:Hide()
    installAnimationStub(region)
    local fade = HoverFade.Attach(region)
    fade.paintVertex(FAINT)
    region:SetAlpha(0)
    fade.paintVertex(FAINT)
    assert(region:GetAlpha() == 0, "repaint while hidden must not raise alpha, got " .. tostring(region:GetAlpha()))
  end

  print("PASS: test_hover_fade")
end
