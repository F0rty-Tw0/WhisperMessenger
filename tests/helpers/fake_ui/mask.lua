-- Opt-in mask stubs (FakeUI.NewFactory({ masks = true })): frames gain
-- CreateMaskTexture() and their textures gain AddMaskTexture(mask). Without
-- the option the fake has neither, like a client without mask textures.
local Mask = {}

-- createFrame builds the mask itself, so it has the usual region methods
-- (SetAllPoints records allPoints).
function Mask.AugmentFrame(frame, createFrame)
  function frame:CreateMaskTexture(childName)
    local mask = createFrame("MaskTexture", childName or (self.name or "frame") .. "Mask", self)
    function mask:SetTexture(path, wrapH, wrapV)
      self.texturePath = path
      self.wrapH = wrapH
      self.wrapV = wrapV
    end
    return mask
  end
end

function Mask.AugmentTexture(texture)
  function texture:AddMaskTexture(mask)
    self.masks = self.masks or {}
    table.insert(self.masks, mask)
  end
end

return Mask
