-- Runs fn with a stubbed C_Texture that knows the template inset bevel
-- atlases (as the live client does), then restores the old global.
local NativeArt = require("WhisperMessenger.UI.Helpers.NativeArt")

local BevelAtlas = {}

local KNOWN = { [NativeArt.INSET_TOP_BEVEL] = true, [NativeArt.INSET_BOTTOM_BEVEL] = true }

function BevelAtlas.With(fn)
  local saved = rawget(_G, "C_Texture")
  rawset(_G, "C_Texture", {
    GetAtlasInfo = function(atlas)
      if KNOWN[atlas] then
        return { width = 256, height = 3 }
      end
      return nil
    end,
  })
  local ok, err = pcall(fn)
  rawset(_G, "C_Texture", saved)
  if not ok then
    error(err, 0)
  end
end

return BevelAtlas
