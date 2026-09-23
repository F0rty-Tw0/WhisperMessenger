local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local RowHoverOverlay = require("WhisperMessenger.UI.ContactsList.RowHoverOverlay")
local SendButtonStyle = require("WhisperMessenger.UI.Composer.SendButtonStyle")
local GhostButton = require("WhisperMessenger.UI.Helpers.GhostButton")

-- The fake textures model WoW's single alpha channel (colour/vertex alpha and
-- SetAlpha overwrite each other). This stub makes every AnimationGroup play
-- instantly: like SetToFinalAlpha(true) it leaves the region at the final
-- alpha, then fires OnFinished.
local function withInstantAnimations(owner)
  local createTexture = owner.CreateTexture
  rawset(owner, "CreateTexture", function(self, ...)
    local texture = createTexture(self, ...)
    rawset(texture, "CreateAnimationGroup", function(region)
      local group = { scripts = {}, playing = false }
      local anim = {}
      function anim:SetDuration() end
      function anim:SetFromAlpha() end
      function anim:SetToAlpha(a)
        anim.to = a
      end
      function group:CreateAnimation()
        return anim
      end
      function group:SetToFinalAlpha() end
      function group:SetScript(name, fn)
        self.scripts[name] = fn
      end
      function group:Stop()
        self.playing = false
      end
      function group:IsPlaying()
        return self.playing
      end
      function group:Play()
        region:SetAlpha(anim.to)
        if self.scripts.OnFinished then
          self.scripts.OnFinished(self)
        end
      end
      return group
    end)
    return texture
  end)
  return owner
end

local MAX_HOVER_ALPHA = 0.08

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")
  local factory = FakeUI.NewFactory()

  -- test_row_hover_effective_alpha_stays_faint
  do
    local row = withInstantAnimations(factory.CreateFrame("Button", nil, nil))
    RowHoverOverlay.ensure(row)
    RowHoverOverlay.update(row, true)
    assert(row.hoverFill.shown == true, "row hover shown")
    assert(row.hoverFill.alpha <= MAX_HOVER_ALPHA, "row hover must stay faint after fade-in, got alpha " .. tostring(row.hoverFill.alpha))
  end

  -- test_send_hover_circle_effective_alpha_stays_faint
  do
    local button = withInstantAnimations(factory.CreateFrame("Button", nil, nil))
    local paint = SendButtonStyle.Create(button)
    paint(false, true)
    local circle = assert(
      FindUI.find(button, function(node)
        return node.texturePath == "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
      end),
      "send button carries a hover circle"
    )
    assert(circle.shown == true, "send hover circle shown")
    assert(circle.alpha <= MAX_HOVER_ALPHA, "send hover circle must stay faint after fade-in, got alpha " .. tostring(circle.alpha))
    assert(circle.alpha >= 0.04, "send hover circle still visible (~0.06)")
  end

  -- test_ghost_hover_effective_alpha_stays_faint
  do
    local button = withInstantAnimations(factory.CreateFrame("Button", nil, nil))
    local label = button:CreateFontString(nil, "OVERLAY")
    local ghost = GhostButton.Attach(button)
    GhostButton.Paint(ghost, label, true)
    assert(ghost.hover.shown == true, "ghost hover shown")
    assert(ghost.hover.alpha <= MAX_HOVER_ALPHA, "ghost hover must stay faint after fade-in, got alpha " .. tostring(ghost.hover.alpha))
  end

  -- test_repaint_after_fade_keeps_alpha
  do
    local row = withInstantAnimations(factory.CreateFrame("Button", nil, nil))
    RowHoverOverlay.ensure(row)
    RowHoverOverlay.update(row, true)
    RowHoverOverlay.ensure(row) -- rebind while hovered repaints the colour
    assert(row.hoverFill.alpha <= MAX_HOVER_ALPHA, "repaint while hovered stays faint, got " .. tostring(row.hoverFill.alpha))
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_hover_fade_alpha")
end
