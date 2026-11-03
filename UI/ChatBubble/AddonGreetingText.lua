local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PlainText = ns.ChatBubblePlainText or require("WhisperMessenger.UI.ChatBubble.PlainText")

-- WM names every addon-sent whisper "Craft Alert": the badge says
-- "Sent by Craft Alert" and the shown text of a tagged whisper calls CraftScan
-- Craft Alert too. Display only; the stored text keeps what was received.
local AddonGreetingText = {}

AddonGreetingText.NAME = "Craft Alert"

-- Spellings matched with plain finds on the segment with only A-Z folded
-- (string.lower alone may fold UTF-8 bytes under a non-C locale), so the
-- localized names (ruRU, koKR, zhCN) match as written.
local SPELLINGS = { "craftscan", "craft scan", "КрафтСкан", "크래프트스캔", "制造扫描" }

-- Lead byte of the UTF-8 character that ends at index.
local function leadByteBefore(text, index)
  local byte = string.byte(text, index)
  while byte and byte >= 0x80 and byte < 0xC0 and index > 1 do
    index = index - 1
    byte = string.byte(text, index)
  end
  return byte
end

-- Letters and digits in ASCII and in two-byte scripts (accented Latin,
-- Cyrillic, Greek) continue a word. CJK and Hangul write particles straight
-- after a name, so their characters never do.
local function isWordLead(byte)
  if byte == nil then
    return false
  end
  if byte >= 0xC2 and byte <= 0xDF then
    return true
  end
  return byte < 0x80 and string.find(string.char(byte), "%w") ~= nil
end

local function isWholeWord(lowered, first, last)
  return not isWordLead(leadByteBefore(lowered, first - 1)) and not isWordLead(string.byte(lowered, last + 1))
end

local function findWord(lowered, spelling, cursor)
  local found, stop = string.find(lowered, spelling, cursor, true)
  while found and not isWholeWord(lowered, found, stop) do
    found, stop = string.find(lowered, spelling, found + 1, true)
  end
  return found, stop
end

local function nextSpelling(lowered, cursor)
  local first, last
  for _, spelling in ipairs(SPELLINGS) do
    local found, stop = findWord(lowered, spelling, cursor)
    if found and (first == nil or found < first) then
      first, last = found, stop
    end
  end
  return first, last
end

local function renameSegment(segment)
  local lowered = string.gsub(segment, "[A-Z]", string.lower)
  local output = {}
  local cursor = 1
  while true do
    local first, last = nextSpelling(lowered, cursor)
    if first == nil then
      break
    end
    output[#output + 1] = string.sub(segment, cursor, first - 1)
    output[#output + 1] = AddonGreetingText.NAME
    cursor = last + 1
  end
  output[#output + 1] = string.sub(segment, cursor)
  return table.concat(output)
end

-- The text a bubble shows for message, before link formatting.
function AddonGreetingText.ForDisplay(message)
  local text = message.text or ""
  if type(message.addonGreeting) ~= "string" or message.addonGreeting == "" then
    return text
  end
  return PlainText.Map(text, renameSegment)
end

-- The stored preview is the raw text of one line; only that line says
-- whether it was tagged, so look it up instead of storing a second preview.
local function previewOf(message, preview)
  if type(message) ~= "table" or message.text ~= preview then
    return preview
  end
  return AddonGreetingText.ForDisplay(message)
end

local function messagesOf(conversation)
  return type(conversation) == "table" and type(conversation.messages) == "table" and conversation.messages or nil
end

-- conversation.lastPreview as shown: the newest line's text.
function AddonGreetingText.ForPreview(conversation, preview)
  local messages = messagesOf(conversation)
  return messages and previewOf(messages[#messages], preview) or preview
end

-- conversation.lastIncomingPreview as shown: the newest incoming whisper's text.
function AddonGreetingText.ForIncomingPreview(conversation, preview)
  local messages = messagesOf(conversation) or {}
  for index = #messages, 1, -1 do
    local message = messages[index]
    if type(message) == "table" and message.direction == "in" and message.kind == "user" then
      return previewOf(message, preview)
    end
  end
  return preview
end

ns.ChatBubbleAddonGreetingText = AddonGreetingText
return AddonGreetingText
