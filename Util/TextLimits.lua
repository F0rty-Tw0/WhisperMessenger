local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Length caps for player-typed text that never split a UTF-8 character.
local TextLimits = {}

-- The game's cap on one chat message.
TextLimits.MESSAGE_MAX_BYTES = 255

-- EditBox:SetMaxBytes counts the null terminator, so one extra byte lets
-- players type a full message.
TextLimits.INPUT_MAX_BYTES = TextLimits.MESSAGE_MAX_BYTES + 1

local function isContinuationByte(byte)
  return byte ~= nil and byte >= 0x80 and byte < 0xC0
end

-- Trimmed text, or nil when blank or not a string.
function TextLimits.Trim(text)
  if type(text) ~= "string" then
    return nil
  end
  local trimmed = string.match(text, "^%s*(.-)%s*$")
  if trimmed == "" then
    return nil
  end
  return trimmed
end

-- Cut to at most maxBytes bytes.
function TextLimits.CapBytes(text, maxBytes)
  if #text <= maxBytes then
    return text
  end
  local cut = maxBytes
  while cut > 0 and isContinuationByte(string.byte(text, cut + 1)) do
    cut = cut - 1
  end
  return string.sub(text, 1, cut)
end

-- Cut to at most maxChars characters.
function TextLimits.CapChars(text, maxChars)
  local chars = 0
  for index = 1, #text do
    if not isContinuationByte(string.byte(text, index)) then
      chars = chars + 1
      if chars > maxChars then
        return string.sub(text, 1, index - 1)
      end
    end
  end
  return text
end

ns.TextLimits = TextLimits
return TextLimits
