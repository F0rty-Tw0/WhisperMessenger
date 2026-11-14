-- Gives fake edit boxes the game's GetFont / SetFont, starting on a font
-- file, like a Blizzard template box whose font object can't be read back.
local FontBox = {}

FontBox.FRIZ = "Fonts\\FRIZQT__.TTF"
FontBox.CHAT = "Fonts\\ARIALN.TTF"

function FontBox.Give(box, path, size, flags)
  box.font = { path, size or 14, flags or "" }
  function box:GetFont()
    return self.font[1], self.font[2], self.font[3]
  end
  function box:SetFont(newPath, newSize, newFlags)
    self.font = { newPath, newSize, newFlags }
  end
  return box
end

-- Wraps factory so every EditBox it makes starts on path.
function FontBox.Factory(factory, path)
  local createFrame = factory.CreateFrame
  local wrapped = setmetatable({}, { __index = factory })
  wrapped.CreateFrame = function(frameType, ...)
    local frame = createFrame(frameType, ...)
    if frameType == "EditBox" and frame then
      FontBox.Give(frame, path)
    end
    return frame
  end
  return wrapped
end

return FontBox
