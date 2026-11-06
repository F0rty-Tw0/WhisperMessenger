local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The phone window growing out of the floating button. A render-only
-- animation: the window's real size and scale never change, so layout and
-- the saved size are untouched. Clients without it just open.
local PhoneOpenAnimation = {}

local function setRange(anim, from)
  if anim.SetScaleFrom then
    anim:SetScaleFrom(from, from)
    anim:SetScaleTo(1, 1)
  else
    anim:SetFromScale(from, from)
    anim:SetToScale(1, 1)
  end
end

function PhoneOpenAnimation.Attach(frame, theme)
  if not frame.CreateAnimationGroup then
    return { play = function(_corner) end }
  end
  local L = theme.LAYOUT
  local group = frame:CreateAnimationGroup()
  local anim = group:CreateAnimation("Scale")
  anim:SetDuration(L.PHONE_OPEN_SECONDS)
  anim:SetSmoothing("OUT")
  setRange(anim, L.PHONE_OPEN_FROM_SCALE)

  return {
    -- corner: the window corner to grow from.
    play = function(corner)
      group:Stop()
      anim:SetOrigin(corner, 0, 0)
      group:Play()
    end,
  }
end

ns.MessengerWindowPhoneOpenAnimation = PhoneOpenAnimation

return PhoneOpenAnimation
