local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Wire format of party-free group chats. One logical packet ("body") is
-- split into frames that each fit one 255-byte addon message:
--
--   frame = "1" .. msgId (4 x [0-9a-z]) .. index (1-9) .. count (1-9) .. chunk
--
-- Bodies, fields joined by "~" (group names and character names never
-- contain one; message text is always the last field):
--
--   M~<id>~<text>               a chat line
--   R~<id>~<name>~<a>,<b>,...   the full member list, sender included
--   L~<id>                      the sender left the group
--   Q~<id>                      the sender asks for the member list
local GroupChats = ns.GroupChats or require("WhisperMessenger.Model.GroupChats")

local GroupChatProtocol = {}

local VERSION = "1"
local MAX_PAYLOAD_BYTES = 255
local HEADER_BYTES = 7
local CHUNK_BYTES = MAX_PAYLOAD_BYTES - HEADER_BYTES
local MAX_FRAMES = 9
local SEPARATOR = "~"
local MESSAGE_ID_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"
local MESSAGE_ID_LENGTH = 4
-- 36 ^ MESSAGE_ID_LENGTH, as an integer.
local MESSAGE_ID_SPACE = 1679616
local REASSEMBLY_TTL = 30
local MAX_PENDING_BODIES = 64

GroupChatProtocol.MAX_BODY_BYTES = CHUNK_BYTES * MAX_FRAMES
GroupChatProtocol.CHUNK_BYTES = CHUNK_BYTES

-- Bodies --------------------------------------------------------------------

function GroupChatProtocol.EncodeMessage(id, text)
  if not GroupChats.IsValidId(id) or type(text) ~= "string" or text == "" then
    return nil
  end
  return "M" .. SEPARATOR .. id .. SEPARATOR .. text
end

-- members: the full list, the sender included.
function GroupChatProtocol.EncodeRoster(id, name, members)
  if not GroupChats.IsValidId(id) or type(members) ~= "table" then
    return nil
  end
  return "R" .. SEPARATOR .. id .. SEPARATOR .. (GroupChats.CleanName(name) or "") .. SEPARATOR .. table.concat(members, ",")
end

function GroupChatProtocol.EncodeLeave(id)
  if not GroupChats.IsValidId(id) then
    return nil
  end
  return "L" .. SEPARATOR .. id
end

function GroupChatProtocol.EncodeQuery(id)
  if not GroupChats.IsValidId(id) then
    return nil
  end
  return "Q" .. SEPARATOR .. id
end

local function decodeMembers(list)
  local members = {}
  for name in string.gmatch(list or "", "[^,]+") do
    if not string.find(name, "[%s|~]") then
      members[#members + 1] = name
    end
  end
  return members
end

-- { kind = "message" | "roster" | "leave" | "query", groupId, ... } or nil.
function GroupChatProtocol.Decode(body)
  if type(body) ~= "string" then
    return nil
  end
  local kind, id, rest = string.match(body, "^(%u)~([a-z0-9]+)(.*)$")
  if kind == nil or not GroupChats.IsValidId(id) then
    return nil
  end
  if kind == "M" then
    local text = string.match(rest, "^~(.+)$")
    if text == nil then
      return nil
    end
    return { kind = "message", groupId = id, text = text }
  end
  if kind == "R" then
    local name, list = string.match(rest, "^~([^~]*)~([^~]*)$")
    if name == nil then
      return nil
    end
    return { kind = "roster", groupId = id, name = GroupChats.CleanName(name), members = decodeMembers(list) }
  end
  if rest ~= "" then
    return nil
  end
  if kind == "L" then
    return { kind = "leave", groupId = id }
  end
  if kind == "Q" then
    return { kind = "query", groupId = id }
  end
  return nil
end

-- Frames --------------------------------------------------------------------

-- counter: a table this client keeps for the session; ids cycle through
-- 36^4 values, plenty for the 30-second reassembly window.
function GroupChatProtocol.NextMessageId(counter, random)
  if counter.value == nil then
    random = random or math.random
    counter.value = random(MESSAGE_ID_SPACE) - 1
  end
  counter.value = (counter.value + 1) % MESSAGE_ID_SPACE
  local value = counter.value
  local chars = {}
  for index = MESSAGE_ID_LENGTH, 1, -1 do
    local digit = value % 36
    chars[index] = string.sub(MESSAGE_ID_ALPHABET, digit + 1, digit + 1)
    value = math.floor(value / 36)
  end
  return table.concat(chars)
end

-- The frames for body, or nil when it needs more than nine.
function GroupChatProtocol.Split(body, messageId)
  if type(body) ~= "string" or body == "" or type(messageId) ~= "string" or #messageId ~= MESSAGE_ID_LENGTH then
    return nil
  end
  local count = math.ceil(#body / CHUNK_BYTES)
  if count > MAX_FRAMES then
    return nil
  end
  local frames = {}
  for index = 1, count do
    local chunk = string.sub(body, (index - 1) * CHUNK_BYTES + 1, index * CHUNK_BYTES)
    frames[index] = VERSION .. messageId .. tostring(index) .. tostring(count) .. chunk
  end
  return frames
end

local function prune(buffer, now)
  local oldestKey, oldestAt
  local size = 0
  for key, entry in pairs(buffer) do
    if now - entry.at > REASSEMBLY_TTL or now < entry.at then
      buffer[key] = nil
    else
      size = size + 1
      if oldestAt == nil or entry.at < oldestAt then
        oldestKey, oldestAt = key, entry.at
      end
    end
  end
  if size > MAX_PENDING_BODIES and oldestKey then
    buffer[oldestKey] = nil
  end
end

-- Feeds one received frame. Returns the whole body once its last frame is
-- in, else nil. buffer: a session table; senderKey: who sent the frame.
function GroupChatProtocol.Receive(buffer, senderKey, frame, now)
  if type(frame) ~= "string" or #frame <= HEADER_BYTES or #frame > MAX_PAYLOAD_BYTES or type(senderKey) ~= "string" then
    return nil
  end
  local version, messageId, index, count = string.match(frame, "^(%d)([0-9a-z][0-9a-z][0-9a-z][0-9a-z])([1-9])([1-9])")
  if version ~= VERSION then
    return nil
  end
  index, count = tonumber(index), tonumber(count)
  if index > count then
    return nil
  end
  local chunk = string.sub(frame, HEADER_BYTES + 1)
  if count == 1 then
    return chunk
  end

  now = now or 0
  prune(buffer, now)
  local key = string.lower(senderKey) .. ":" .. messageId
  local entry = buffer[key]
  if entry == nil or entry.count ~= count then
    entry = { count = count, parts = {}, received = 0, at = now }
    buffer[key] = entry
  end
  if entry.parts[index] == nil then
    entry.parts[index] = chunk
    entry.received = entry.received + 1
  end
  if entry.received < count then
    return nil
  end
  buffer[key] = nil
  return table.concat(entry.parts, "", 1, count)
end

ns.GroupChatProtocol = GroupChatProtocol
return GroupChatProtocol
