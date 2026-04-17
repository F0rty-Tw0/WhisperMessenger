-- Augments a frame created with frameType "Texture" with texture-specific
-- methods.  Called from createFrame in frame.lua when type is "Texture".
local Texture = {}

function Texture.Augment(frame)
  function frame:SetColorTexture(...)
    self.color = { ... }
  end

  function frame:SetTexture(path)
    self.texturePath = path
  end

  function frame:GetTexture()
    return self.texturePath
  end

  function frame:SetVertexColor(...)
    self.vertexColor = { ... }
  end

  function frame:SetDesaturated(value)
    self.desaturated = value
  end

  function frame:SetTexCoord(...)
    self.texCoords = { ... }
  end

  function frame:SetMask(mask)
    self.mask = mask
  end

  function frame:SetAtlas(atlas)
    self.atlas = atlas
  end

  function frame:SetBlendMode(mode)
    self.blendMode = mode
  end
end

return Texture
