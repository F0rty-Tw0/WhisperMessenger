-- Opt-in word-wrap stubs (FakeUI.NewFactory({ wrap = true })): a FontString
-- with SetWordWrap(true) and a width counts wrapped lines, 7 px per character
-- (the GetStringWidth metric), and GetStringHeight is lines x font size.
-- Without the option a FontString counts only its "\n" lines.
local Wrap = {}

local CHAR_WIDTH = 7

local function wrappedLines(text, width)
  local perLine = math.max(1, math.floor(width / CHAR_WIDTH))
  local lines = 0
  local from = 1
  while true do
    local newline = string.find(text, "\n", from, true)
    local part = string.sub(text, from, (newline or #text + 1) - 1)
    lines = lines + math.max(1, math.ceil(#part / perLine))
    if not newline then
      return lines
    end
    from = newline + 1
  end
end

local function isWrapping(fontString)
  return fontString.wordWrap == true and (fontString.width or 0) > 0
end

function Wrap.AugmentFontString(fontString)
  local plainNumLines = fontString.GetNumLines
  local plainStringHeight = fontString.GetStringHeight

  function fontString:GetNumLines()
    if not isWrapping(self) then
      return plainNumLines(self)
    end
    return wrappedLines(tostring(self.text or ""), self.width)
  end

  function fontString:GetStringHeight()
    if not isWrapping(self) then
      return plainStringHeight(self)
    end
    local font = self:GetFontObject()
    local size
    if font and font.GetFont then
      local _, fontSize = font:GetFont()
      size = fontSize
    end
    if type(size) ~= "number" or size <= 0 then
      size = self.lineHeight or 16
    end
    return self:GetNumLines() * size
  end
end

return Wrap
