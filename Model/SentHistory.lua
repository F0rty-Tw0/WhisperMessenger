local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
local MessageMetadata = ns.ConversationStoreMessageMetadata or require("WhisperMessenger.Model.ConversationStore.MessageMetadata")

local tonumber = tonumber
local tostring = tostring

-- Lines the player sent, newest first, across every saved chat and every
-- character. Queued and failed lines count too, so they can be sent again.
local SentHistory = {}

SentHistory.MAX_ENTRIES = 50

-- The secret check comes first: a secret value raises on any comparison.
local function usableText(text, fits)
  if SecretValue.Is(text) or type(text) ~= "string" or text == "" then
    return false
  end
  return fits == nil or fits(text)
end

-- Newest first; on a same-second tie the later line of a chat comes first.
local function newerFirst(left, right)
  if left.sentAt ~= right.sentAt then
    return left.sentAt > right.sentAt
  end
  if left.key ~= right.key then
    return tostring(left.key) < tostring(right.key)
  end
  return left.index > right.index
end

-- The chat's length as ipairs sees it, and whether sentAt never goes down
-- along it. Nothing in the store keeps lines in time order (plain appends
-- take the time they are given), so this is checked on every Build. A NaN
-- time compares false both ways and would hide disorder, so it counts as out
-- of order.
local function scan(messages)
  local count, previous, ordered = 0, -math.huge, true
  local message = messages[1]
  while message ~= nil do
    local sentAt = tonumber(message.sentAt) or 0
    if sentAt < previous or sentAt ~= sentAt then
      ordered = false
    end
    previous = sentAt
    count = count + 1
    message = messages[count + 1]
  end
  return count, ordered
end

-- A chat out of time order: its usable lines, sorted newest first.
local function collectSorted(key, messages, fits)
  local entries = {}
  for index, message in ipairs(messages) do
    if MessageMetadata.IsOutgoingUser(message) and usableText(message.text, fits) then
      entries[#entries + 1] = { text = message.text, sentAt = tonumber(message.sentAt) or 0, key = key, index = index }
    end
  end
  table.sort(entries, newerFirst)
  return entries
end

-- Each chat has a cursor on its newest line not taken yet (its head). A chat
-- in time order walks its messages backward; any other chat walks its sorted
-- entries forward. Returns false once the chat has no usable line left.
local function advance(merge, chat, fits)
  local list = merge.lists[chat]
  if merge.sorted[chat] then
    local position = merge.positions[chat] + 1
    local entry = list[position]
    if entry == nil then
      return false
    end
    merge.positions[chat], merge.sentAts[chat] = position, entry.sentAt
    return true
  end
  for index = merge.positions[chat] - 1, 1, -1 do
    local message = list[index]
    if MessageMetadata.IsOutgoingUser(message) and usableText(message.text, fits) then
      merge.positions[chat], merge.sentAts[chat] = index, tonumber(message.sentAt) or 0
      return true
    end
  end
  return false
end

local function openChat(merge, chat, key, messages, fits)
  local count, ordered = scan(messages)
  merge.names[chat] = tostring(key)
  if ordered then
    merge.lists[chat], merge.positions[chat], merge.sorted[chat] = messages, count + 1, nil
  else
    merge.lists[chat], merge.positions[chat], merge.sorted[chat] = collectSorted(key, messages, fits), 0, true
  end
  return advance(merge, chat, fits)
end

-- newerFirst for two heads. Heads come from different chats, so the line
-- index never decides.
local function headNewer(merge, left, right)
  local leftAt, rightAt = merge.sentAts[left], merge.sentAts[right]
  if leftAt ~= rightAt then
    return leftAt > rightAt
  end
  return merge.names[left] < merge.names[right]
end

-- Restores the heap below slot, with the newest head on top.
local function siftDown(merge, heap, size, slot)
  while true do
    local child = slot * 2
    if child > size then
      return
    end
    if child < size and headNewer(merge, heap[child + 1], heap[child]) then
      child = child + 1
    end
    if not headNewer(merge, heap[child], heap[slot]) then
      return
    end
    heap[slot], heap[child] = heap[child], heap[slot]
    slot = child
  end
end

local function openHeap(merge, conversations, fits)
  local heap, size = {}, 0
  for key, conversation in pairs(conversations) do
    if type(conversation) == "table" and type(conversation.messages) == "table" then
      if openChat(merge, size + 1, key, conversation.messages, fits) then
        size = size + 1
        heap[size] = size
      end
    end
  end
  for slot = math.floor(size / 2), 1, -1 do
    siftDown(merge, heap, size, slot)
  end
  return heap, size
end

-- fits (optional) drops lines the open chat would refuse. It runs before
-- neighbouring duplicates collapse, so a dropped line never splits a run.
-- Merges the chats' newest-first streams, so nothing is allocated per stored
-- line; each chat is still scanned once for time order.
function SentHistory.Build(conversations, fits)
  if type(conversations) ~= "table" then
    return {}
  end
  local merge = { names = {}, lists = {}, positions = {}, sentAts = {}, sorted = {} }
  local heap, size = openHeap(merge, conversations, fits)
  local list = {}
  while size > 0 and #list < SentHistory.MAX_ENTRIES do
    local chat = heap[1]
    local text = merge.lists[chat][merge.positions[chat]].text
    if text ~= list[#list] then
      list[#list + 1] = text
    end
    if not advance(merge, chat, fits) then
      heap[1] = heap[size]
      heap[size] = nil
      size = size - 1
    end
    siftDown(merge, heap, size, 1)
  end
  return list
end

ns.SentHistory = SentHistory
return SentHistory
