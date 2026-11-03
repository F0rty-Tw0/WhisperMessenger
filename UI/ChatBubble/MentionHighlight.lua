local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Mention = ns.GroupChatIngestMention or require("WhisperMessenger.Core.Ingest.GroupChatIngest.Mention")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local PlainText = ns.ChatBubblePlainText or require("WhisperMessenger.UI.ChatBubble.PlainText")

-- Paints the player's name in their class colour inside a bubble that
-- mentions them. Works on display text, so every escape sequence (links,
-- colour runs, textures, atlases, protected names) is copied byte-exact.
local MentionHighlight = {}

local function colorizeSegment(segment, name, open)
  local output = {}
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
  return table.concat(output)
end

-- hex is the 8-digit AARRGGBB form a |c code takes.
function MentionHighlight.Colorize(text, name, hex)
  if type(text) ~= "string" or type(name) ~= "string" or name == "" or type(hex) ~= "string" then
    return text
  end
  local open = "|c" .. hex
  return PlainText.Map(text, function(segment)
    return colorizeSegment(segment, name, open)
  end)
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
