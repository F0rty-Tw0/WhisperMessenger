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

-- Lower-case spellings, matched with plain finds on the lower-cased segment.
local SPELLINGS = { "craftscan", "craft scan" }

local function nextSpelling(lowered, cursor)
  local first, last
  for _, spelling in ipairs(SPELLINGS) do
    local found, stop = string.find(lowered, spelling, cursor, true)
    if found and (first == nil or found < first) then
      first, last = found, stop
    end
  end
  return first, last
end

local function renameSegment(segment)
  local lowered = string.lower(segment)
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

ns.ChatBubbleAddonGreetingText = AddonGreetingText
return AddonGreetingText
