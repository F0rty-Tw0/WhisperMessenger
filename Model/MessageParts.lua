local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")

-- A long whisper goes out as several whispers sharing one wire id. Part 1
-- pairs through the usual identity payload; the rest pair through one
-- manifest on the same WMRX prefix:
--
--   1|P|<wireId>|<n>|<fp2>,<fp3>,...|<joins>
--
-- joins has one char per part 2..n: "s" (a space goes before the part) or
-- "n" (nothing does). Older versions reject kind "P", so a recipient
-- without this sees parts 2..n as plain whispers.
local MessageParts = {}

local PART_FIELDS = { "partIndex", "partCount", "join" }
local JOIN_CODES = { [" "] = "s", [""] = "n" }
local JOINS = { s = " ", n = "" }
-- Parts of one message arrive within seconds, so they sit near the end.
local SCAN_WINDOW = 10

-- Copies the part fields of src (identity record or pending send) onto
-- message.
function MessageParts.ApplyMetadata(message, src)
  if type(message) ~= "table" or type(src) ~= "table" then
    return message
  end
  for _, field in ipairs(PART_FIELDS) do
    if src[field] ~= nil then
      message[field] = src[field]
    end
  end
  return message
end

-- parts: { { text, join }, ... } with each text in its transport form.
function MessageParts.EncodeManifest(wireId, parts)
  if not Protocol.IsWireId(wireId) or type(parts) ~= "table" or #parts < 2 then
    return nil
  end
  local fingerprints, joins = {}, {}
  for index = 2, #parts do
    fingerprints[#fingerprints + 1] = Protocol.Fingerprint(parts[index].text)
    joins[#joins + 1] = JOIN_CODES[parts[index].join or ""] or "n"
  end
  local payload = table.concat({ Protocol.VERSION, "P", wireId, tostring(#parts), table.concat(fingerprints, ","), table.concat(joins) }, "|")
  if #payload > Protocol.MAX_PAYLOAD_BYTES then
    return nil
  end
  return payload
end

-- { type = "manifest", wireId, partCount, records } where records holds one
-- identity record per part 2..n for the usual fingerprint pairing; nil when
-- malformed.
function MessageParts.DecodeManifest(payload)
  if type(payload) ~= "string" then
    return nil
  end
  local version, wireId, countText, fingerprintList, joinCodes = string.match(payload, "^([^|]*)|P|([^|]*)|(%d+)|([^|]*)|([sn]*)$")
  if version ~= Protocol.VERSION or not Protocol.IsWireId(wireId) then
    return nil
  end
  local partCount = tonumber(countText)
  if partCount < 2 or #joinCodes ~= partCount - 1 then
    return nil
  end
  local records = {}
  for fingerprint in string.gmatch(fingerprintList .. ",", "([^,]*),") do
    local partIndex = #records + 2
    if not Protocol.IsFingerprint(fingerprint) or partIndex > partCount then
      return nil
    end
    records[#records + 1] = {
      type = "identity",
      wireId = wireId,
      sourceFingerprint = fingerprint,
      partIndex = partIndex,
      partCount = partCount,
      join = JOINS[string.sub(joinCodes, partIndex - 1, partIndex - 1)],
    }
  end
  if #records ~= partCount - 1 then
    return nil
  end
  return { type = "manifest", wireId = wireId, partCount = partCount, records = records }
end

-- The user messages near the end of messages with this wire id, in order.
local function collectParts(messages, wireId, direction)
  local found = {}
  for index = math.max(1, #messages - SCAN_WINDOW + 1), #messages do
    local message = messages[index]
    if message.wireId == wireId and message.kind == "user" and (direction == nil or message.direction == direction) then
      found[#found + 1] = message
    end
  end
  return found
end

-- A message without part fields is part 1 (its identity has no index).
local function partIndexOf(message)
  return message.partIndex or 1
end

-- Present parts in index order, each after its join; gaps are skipped.
local function joinParts(parts, lastIndex)
  local pieces = {}
  for index = 1, lastIndex do
    local part = parts[index]
    if part ~= nil then
      if #pieces > 0 then
        pieces[#pieces + 1] = part.join or ""
      end
      pieces[#pieces + 1] = part.text
    end
  end
  return table.concat(pieces)
end

local function highestIndex(parts, partCount)
  local highest = partCount or 0
  for index in pairs(parts) do
    highest = math.max(highest, index)
  end
  return highest
end

local function isComplete(parts, partCount)
  if partCount == nil then
    return false
  end
  for index = 1, partCount do
    if parts[index] == nil then
      return false
    end
  end
  return true
end

local function removeAbsorbed(messages, absorbed)
  for index = #messages, 1, -1 do
    if absorbed[messages[index]] then
      table.remove(messages, index)
    end
  end
end

local function updatePreviews(conversation, host)
  local messages = conversation.messages
  if messages[#messages] == host then
    conversation.lastPreview = host.text
  end
  if host.direction ~= "in" then
    return
  end
  for index = #messages, 1, -1 do
    local message = messages[index]
    if message.kind == "user" and message.direction == "in" then
      if message == host then
        conversation.lastIncomingPreview = host.text
      end
      return
    end
  end
end

-- Folds the stored parts of one long whisper into its earliest-placed part
-- (the host). Partial text shows until the late parts arrive; host.parts
-- keeps the part texts until all of them are in. Order-independent and
-- idempotent. Returns true when anything was folded in.
function MessageParts.Merge(conversation, wireId, direction)
  local messages = type(conversation) == "table" and conversation.messages or nil
  if type(messages) ~= "table" or wireId == nil then
    return false
  end
  local found = collectParts(messages, wireId, direction)
  if #found < 2 then
    return false
  end

  local host = found[1]
  local parts = host.parts or { [partIndexOf(host)] = { text = host.text, join = host.join } }
  local partCount = host.partCount
  local absorbed = {}
  local absorbedIncoming = 0
  for index = 2, #found do
    local message = found[index]
    local partIndex = partIndexOf(message)
    parts[partIndex] = parts[partIndex] or { text = message.text, join = message.join }
    partCount = partCount or message.partCount
    host.replyTo = host.replyTo or message.replyTo
    host.reaction = host.reaction or message.reaction
    absorbed[message] = true
    if message.direction == "in" then
      absorbedIncoming = absorbedIncoming + 1
    end
  end
  removeAbsorbed(messages, absorbed)

  host.partCount = partCount
  host.text = joinParts(parts, highestIndex(parts, partCount))
  if isComplete(parts, partCount) then
    host.parts = nil
  else
    host.parts = parts
  end
  conversation.unreadCount = math.max(0, (conversation.unreadCount or 0) - absorbedIncoming)
  updatePreviews(conversation, host)
  return true
end

ns.MessageParts = MessageParts
return MessageParts
