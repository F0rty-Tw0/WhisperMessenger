local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Side-channel for quest links over character whispers.
--
-- Background: WoW Classic's character-whisper protocol strips both the
-- `|H...|h` envelope and any `(id)` from `[Name (id)]` text, so the
-- recipient's chat receives only `[Name]` no matter how we serialize the
-- outgoing message. To restore clickability we ship the id and name over
-- the addon-message channel (255-byte cap, separate wire) and splice them
-- back into the chat text on receive.
--
-- Payload wire format: `id1:name1;id2:name2;…` with a hard byte cap so the
-- caller can hand the result straight to `AddonComm.Send`.

local QuestLinkExchange = {}

local MAX_PAYLOAD_BYTES = 255
local INBOX_TTL_SECONDS = 15

local QUEST_LINK_HYPERLINK_PATTERN = "|Hquest:(%d+)[^|]*|h%[([^%]]+)%]|h"
local QUEST_LINK_PLAIN_PATTERN = "%[([^%[%]|]+) %((%d+)%)%]"

local function entrySize(id, name)
  -- `<id>:<name>;` — the trailing `;` is dropped on the last entry, but
  -- budgeting for it keeps the cap check simple.
  return #id + 1 + #name + 1
end

local function appendEntry(parts, totalBytes, id, name)
  local newSize = totalBytes + entrySize(id, name)
  -- The trailing `;` is dropped on the last entry, so the budget is one byte
  -- over the cap. Skip entries that would push the join past it.
  if newSize > MAX_PAYLOAD_BYTES + 1 then
    return totalBytes
  end
  table.insert(parts, id .. ":" .. name)
  return newSize
end

-- Returns (matchEnd, id, name) for the earliest quest reference at or after
-- `cursor`, picking whichever form (hyperlink vs plain) appears first.
local function findNextQuestRef(text, cursor)
  local hStart, hEnd, hId, hName = string.find(text, QUEST_LINK_HYPERLINK_PATTERN, cursor)
  local pStart, pEnd, pName, pId = string.find(text, QUEST_LINK_PLAIN_PATTERN, cursor)

  if hStart and (not pStart or hStart <= pStart) then
    return hEnd, hId, hName
  end
  if pStart then
    return pEnd, pId, pName
  end
  return nil
end

function QuestLinkExchange.Encode(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end

  local parts = {}
  local seen = {}
  local totalBytes = 0
  local cursor = 1

  while cursor <= #text do
    local matchEnd, id, name = findNextQuestRef(text, cursor)
    if matchEnd == nil then
      break
    end

    local key = id .. "\0" .. name
    if not seen[key] then
      seen[key] = true
      totalBytes = appendEntry(parts, totalBytes, id, name)
    end
    cursor = matchEnd + 1
  end

  if #parts == 0 then
    return nil
  end
  return table.concat(parts, ";")
end

local function purgeExpired(inbox, now)
  for index = #inbox, 1, -1 do
    if (now - inbox[index].recordedAt) > INBOX_TTL_SECONDS then
      table.remove(inbox, index)
    end
  end
end

local function purgeExpiredInbox(state, now)
  local inboxBySender = state.questLinkInbox
  if type(inboxBySender) ~= "table" then
    return
  end

  for sender, inbox in pairs(inboxBySender) do
    if type(inbox) == "table" then
      purgeExpired(inbox, now)
      if #inbox == 0 then
        inboxBySender[sender] = nil
      end
    else
      inboxBySender[sender] = nil
    end
  end
end

function QuestLinkExchange.RecordIncoming(state, sender, payload, now)
  if type(state) ~= "table" or type(sender) ~= "string" or type(payload) ~= "string" then
    return
  end
  state.questLinkInbox = state.questLinkInbox or {}
  purgeExpiredInbox(state, type(now) == "number" and now or 0)
  state.questLinkInbox[sender] = state.questLinkInbox[sender] or {}

  local inbox = state.questLinkInbox[sender]
  for entry in string.gmatch(payload, "[^;]+") do
    local id, name = string.match(entry, "^(%d+):(.+)$")
    if id and name then
      table.insert(inbox, { id = id, name = name, recordedAt = now })
    end
  end
end


local function buildHyperlink(id, name)
  return string.format("|cffffff00|Hquest:%s:0|h[%s]|h|r", id, name)
end

local function escapePatternLiteral(literal)
  return (string.gsub(literal, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

function QuestLinkExchange.Splice(state, sender, text, now)
  if type(state) ~= "table" or type(sender) ~= "string" or type(text) ~= "string" then
    return text
  end
  local inbox = state.questLinkInbox and state.questLinkInbox[sender]
  if type(inbox) ~= "table" or #inbox == 0 then
    return text
  end

  purgeExpired(inbox, type(now) == "number" and now or 0)

  local result = text
  for index = #inbox, 1, -1 do
    local entry = inbox[index]
    local plainBracket = "[" .. entry.name .. "]"
    local pattern = escapePatternLiteral(plainBracket)
    -- Only splice when the bracketed name isn't already inside a `|H...|h`
    -- envelope. We check that by ensuring no `|h` follows the closing
    -- bracket immediately (hyperlink form ends with `]|h|r`).
    local replaced = false
    local rewritten = string.gsub(result, pattern .. "(.?.?)", function(suffix)
      if suffix == "|h" then
        return nil
      end
      replaced = true
      return buildHyperlink(entry.id, entry.name) .. suffix
    end, 1)
    if replaced then
      result = rewritten
      table.remove(inbox, index)
    end
  end

  if #inbox == 0 then
    state.questLinkInbox[sender] = nil
  end

  return result
end

QuestLinkExchange.MAX_PAYLOAD_BYTES = MAX_PAYLOAD_BYTES
QuestLinkExchange.INBOX_TTL_SECONDS = INBOX_TTL_SECONDS

ns.QuestLinkExchange = QuestLinkExchange

return QuestLinkExchange
