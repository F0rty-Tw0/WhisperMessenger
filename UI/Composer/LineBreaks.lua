local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local LineBreaks = {}

local BREAK = "[\r\n]"

local find = string.find
local sub = string.sub

-- Returns the last byte index of the break that starts at `start`.
local function breakEnd(text, start)
  if sub(text, start, start + 1) == "\r\n" then
    return start + 1
  end

  return start
end

-- A message never holds a line break. A text holding exactly one break that is
-- its last character and ends at the cursor was typed (Enter): drop it.
-- Anything else is a paste: each break becomes a space.
function LineBreaks.Flatten(text, cursor)
  local first = find(text, BREAK)
  if not first then
    return text, cursor
  end

  local firstEnd = breakEnd(text, first)
  local isSingle = not find(text, BREAK, firstEnd + 1)
  local isTyped = isSingle and firstEnd == #text and firstEnd == cursor
  if isTyped then
    return sub(text, 1, first - 1), cursor - (firstEnd - first + 1)
  end

  local parts = {}
  local from = 1
  local newCursor = cursor
  local start = find(text, BREAK, first)
  while start do
    local stop = breakEnd(text, start)
    parts[#parts + 1] = sub(text, from, start - 1)
    if stop > start and stop <= cursor then
      newCursor = newCursor - 1
    end
    from = stop + 1
    start = find(text, BREAK, from)
  end
  parts[#parts + 1] = sub(text, from)

  return table.concat(parts, " "), newCursor
end

ns.ComposerLineBreaks = LineBreaks
return LineBreaks
