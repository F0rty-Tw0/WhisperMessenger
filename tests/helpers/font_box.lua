-- Starts fake edit boxes on a font file (GetFont / SetFont come from the
-- fake frame), like a Blizzard template box whose font object can't be read back.
local FontBox = {}

FontBox.FRIZ = "Fonts\\FRIZQT__.TTF"
FontBox.CHAT = "Fonts\\ARIALN.TTF"

function FontBox.Give(box, path, size, flags)
  box:SetFont(path, size or 14, flags or "")
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
