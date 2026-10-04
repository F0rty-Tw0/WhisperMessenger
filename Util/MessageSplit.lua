local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Splits a message into whisper-sized parts without cutting a word, a link,
-- an escape code or a UTF-8 character.
local MessageSplit = {}

local stringByte = string.byte
local stringFind = string.find
local stringSub = string.sub

local function isContinuationByte(byte)
  return byte ~= nil and byte >= 0x80 and byte < 0xC0
end

local function characterEnd(text, index)
  local finish = index
  while isContinuationByte(stringByte(text, finish + 1)) do
    finish = finish + 1
  end
  return finish
end

local PIPE = 124
local OPEN_BRACKET = 91
-- `[Name (id)]`, the Classic wire form of a quest link.
local CLASSIC_QUEST_PATTERN = "^%[[^%[%]|]+ %(%d+%)%]"
local COLOUR_PATTERNS = { "^|c%x%x%x%x%x%x%x%x", "^|cn[^:|]*:" }
local CLOSERS = { T = "|t", A = "|a", K = "|k" }
local TWO_BYTE_ESCAPES = { ["|"] = true, n = true, r = true }

local function find(text, pattern, index)
  local _, finish = stringFind(text, pattern, index)
  return finish
end

local function findPlain(text, needle, index)
  local _, finish = stringFind(text, needle, index, true)
  return finish
end

-- `|H data |h label |h`
local function linkEnd(text, index)
  local dataEnd = findPlain(text, "|h", index + 2)
  return dataEnd and findPlain(text, "|h", dataEnd + 1)
end

-- A colour token, or the whole `|c…|H…|h…|h|r` when it wraps a link.
local function colourEnd(text, index)
  local tokenEnd = find(text, COLOUR_PATTERNS[1], index) or find(text, COLOUR_PATTERNS[2], index)
  if not tokenEnd or stringSub(text, tokenEnd + 1, tokenEnd + 2) ~= "|H" then
    return tokenEnd
  end
  local finish = linkEnd(text, tokenEnd + 1)
  if finish and stringSub(text, finish + 1, finish + 2) == "|r" then
    return finish + 2
  end
  return tokenEnd
end

local function escapeEnd(text, index)
  local code = stringSub(text, index + 1, index + 1)
  if code == "c" then
    return colourEnd(text, index)
  elseif code == "H" then
    return linkEnd(text, index)
  elseif CLOSERS[code] then
    return findPlain(text, CLOSERS[code], index + 2)
  elseif TWO_BYTE_ESCAPES[code] then
    return index + 1
  end
  return nil
end

-- Last byte of the unit starting at index, and whether it is whitespace.
local function unitEnd(text, index)
  local spaceEnd = find(text, "^%s+", index)
  if spaceEnd then
    return spaceEnd, true
  end
  local byte = stringByte(text, index)
  local finish
  if byte == PIPE then
    finish = escapeEnd(text, index)
  elseif byte == OPEN_BRACKET then
    finish = find(text, CLASSIC_QUEST_PATTERN, index)
  end
  return finish or characterEnd(text, index), false
end

-- Calls emit(first, last, join) for each part's byte range.
local function pack(text, partBytes, emit)
  local length = #text
  local partStart = 1
  local join
  local lastSpaceStart, lastSpaceEnd
  local index = 1

  local function emitPart(last, nextStart, nextJoin)
    emit(partStart, last, join)
    partStart = nextStart
    join = nextJoin
    lastSpaceStart = nil
  end

  while index <= length do
    local finish, isSpace = unitEnd(text, index)
    if finish - partStart + 1 <= partBytes then
      if isSpace and index > partStart then
        lastSpaceStart, lastSpaceEnd = index, finish
      end
      index = finish + 1
    elseif index == partStart then
      local spaceEnd = find(text, "^%s+", finish + 1)
      if spaceEnd then
        emitPart(finish, spaceEnd + 1, " ")
      else
        emitPart(finish, finish + 1, "")
      end
      index = partStart
    elseif isSpace then
      emitPart(index - 1, finish + 1, " ")
      index = finish + 1
    elseif lastSpaceStart then
      emitPart(lastSpaceStart - 1, lastSpaceEnd + 1, " ")
    else
      emitPart(index - 1, index, "")
    end
  end

  if partStart <= length then
    emit(partStart, length, join)
  end
end

-- Array of { text, join }; join is the separator that goes before the part
-- (" " for a dropped whitespace run, "" for a hard cut, nil on part 1).
function MessageSplit.Split(text, partBytes)
  if #text <= partBytes then
    return { { text = text } }
  end
  local parts = {}
  pack(text, partBytes, function(first, last, join)
    parts[#parts + 1] = { text = stringSub(text, first, last), join = join }
  end)
  return parts
end

function MessageSplit.Count(text, partBytes)
  if #text <= partBytes then
    return 1
  end
  local count = 0
  pack(text, partBytes, function()
    count = count + 1
  end)
  return count
end

ns.MessageSplit = MessageSplit
return MessageSplit
