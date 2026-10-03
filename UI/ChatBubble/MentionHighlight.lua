local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Mention = ns.GroupChatIngestMention or require("WhisperMessenger.Core.Ingest.GroupChatIngest.Mention")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")

-- Paints the player's name in their class colour inside a bubble that
-- mentions them. Works on display text, so every escape sequence (links,
-- colour runs, textures, atlases, protected names) is copied byte-exact.
local MentionHighlight = {}

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

local function colorizeSegment(segment, name, open, output)
  local cursor = 1
  while true do
    local first, last = Mention.FindWord(segment, name, cursor)
    if first == nil then
      break
    end
    output[#output + 1] = string.sub(segment, cursor, first - 1)
    output[#output + 1] = open .. string.sub(segment, first, last) .. "|r"
    cursor = last + 1
  end
  output[#output + 1] = string.sub(segment, cursor)
end

-- hex is the 8-digit AARRGGBB form a |c code takes.
function MentionHighlight.Colorize(text, name, hex)
  if type(text) ~= "string" or type(name) ~= "string" or name == "" or type(hex) ~= "string" then
    return text
  end
  local open = "|c" .. hex
  local output = {}
  local cursor = 1
  local length = #text
  while cursor <= length do
    local pipeAt = string.find(text, "|", cursor, true) or (length + 1)
    if pipeAt > cursor then
      colorizeSegment(string.sub(text, cursor, pipeAt - 1), name, open, output)
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

local function toByte(value)
  return math.floor(value * 255 + 0.5)
end

function MentionHighlight.ClassHex(classTag)
  local colors = _G.RAID_CLASS_COLORS
  local color = type(classTag) == "string" and type(colors) == "table" and colors[classTag] or nil
  if type(color) ~= "table" or type(color.r) ~= "number" then
    return nil
  end
  return string.format("ff%02x%02x%02x", toByte(color.r), toByte(color.g), toByte(color.b))
end

-- The class cannot change during a session; cache once the game reports it.
local playerHex = nil

function MentionHighlight.Apply(text)
  if playerHex == nil then
    playerHex = MentionHighlight.ClassHex(LocalPlayer.ClassTag())
  end
  return MentionHighlight.Colorize(text, Mention.PlayerName(), playerHex)
end

ns.ChatBubbleMentionHighlight = MentionHighlight
return MentionHighlight
