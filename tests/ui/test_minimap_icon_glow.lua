local FakeUI = require("tests.helpers.fake_ui")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")

local INNER_GLOW_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\inner-glow.png"

-- Factory whose frames record the animation kinds their groups create.
local function newAnimatedFactory()
  local raw = FakeUI.NewFactory()
  local function CreateFrame(...)
    local f = raw.CreateFrame(...)
    if type(f) == "table" and f.frameType == "Frame" then
      function f:CreateAnimationGroup()
        local ag = { animations = {} }
        function ag:SetLooping() end
        function ag:SetScript() end
        function ag:CreateAnimation(kind)
          local anim = { kind = kind }
          setmetatable(anim, {
            __index = function()
              return function() end
            end,
          })
          table.insert(self.animations, anim)
          return anim
        end
        f.animationGroup = ag
        return ag
      end
    end
    return f
  end
  return { CreateFrame = CreateFrame }
end

return function()
  local factory = newAnimatedFactory()
  local parent = factory.CreateFrame("Frame", "Minimap", nil)
  parent:SetSize(140, 140)
  local icon = MinimapIcon.Create(factory, { parent = parent })
  local glow = icon.pulseGlow

  -- test_minimap_glow_uses_inner_glow_texture
  assert(glow ~= nil, "minimap icon exposes its pulse glow")
  assert(
    glow.glowTexture.texturePath == INNER_GLOW_TEXTURE,
    "minimap glow uses the inner glow texture, got " .. tostring(glow.glowTexture.texturePath)
  )
  assert(glow.glowTexture.atlas == nil, "minimap glow drops the outer halo atlas")

  -- test_minimap_glow_matches_icon_size
  assert(glow.glowFrame.width == icon.frame.width, "minimap glow is sized 1:1 with the icon, got " .. tostring(glow.glowFrame.width))
  assert(glow.glowFrame.height == icon.frame.height, "minimap glow height matches the icon")

  -- test_minimap_glow_has_no_scale_animation
  for _, anim in ipairs(glow.animation.animations) do
    assert(anim.kind == "Alpha", "minimap glow only animates alpha, found " .. tostring(anim.kind))
  end

  print("PASS: test_minimap_icon_glow")
end
