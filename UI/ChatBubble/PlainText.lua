local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Rewrites the plain text of a chat line while every escape sequence (links,
-- colour runs, textures, atlases, protected names) is copied byte-exact.
local PlainText = {}

-- Escape codes with a body, and the code that closes it.
local ESCAPE_CLOSERS = { c = "|r", T = "|t", A = "|a", K = "|k" }

-- Last byte of the escape sequence that starts at pipeAt. An unclosed
-- sequence runs to the end of the text.
local function escapeEnd(text, pipeAt)
  local code = string.sub(text, pipeAt + 1, pipeAt + 1)
  if code == "H" then
    local _, dataEnd = string.find(text, "|h", pipeAt + 2, true)
    if dataEnd == nil then
      return #text
    end
    local _, linkEnd = string.find(text, "|h", dataEnd + 1, true)
    return linkEnd or #text
  end
  local closer = ESCAPE_CLOSERS[code]
  if closer then
    local _, stop = string.find(text, closer, pipeAt + 2, true)
    return stop or #text
  end
  return pipeAt + 1
end

-- rewrite(segment) returns the text that replaces one plain segment.
function PlainText.Map(text, rewrite)
  if type(text) ~= "string" then
    return text
  end
  local output = {}
  local cursor = 1
  local length = #text
  while cursor <= length do
    local pipeAt = string.find(text, "|", cursor, true) or (length + 1)
    if pipeAt > cursor then
      output[#output + 1] = rewrite(string.sub(text, cursor, pipeAt - 1))
    end
    if pipeAt > length then
      break
    end
    local stop = escapeEnd(text, pipeAt)
    output[#output + 1] = string.sub(text, pipeAt, stop)
    cursor = stop + 1
  end
  return table.concat(output)
end

ns.ChatBubblePlainText = PlainText
return PlainText
