local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

-- Canned texts the composer can insert. Saved account-wide as
-- settings.quickReplies; nil means "never edited" and shows the localized
-- defaults, so existing installs need no migration.
local QuickReplies = {}

QuickReplies.MAX_ENTRIES = 10

local DEFAULT_KEYS = {
  "One sec",
  "On my way",
  "Sure!",
  "Sorry, busy right now — will reply soon",
}

function QuickReplies.List(saved)
  if type(saved) == "table" then
    return saved
  end
  local defaults = {}
  for index, key in ipairs(DEFAULT_KEYS) do
    defaults[index] = Localization.Text(key)
  end
  return defaults
end

local function copyList(saved)
  local copy = {}
  for index, text in ipairs(QuickReplies.List(saved)) do
    copy[index] = text
  end
  return copy
end

function QuickReplies.CanAdd(saved)
  return #QuickReplies.List(saved) < QuickReplies.MAX_ENTRIES
end

-- Returns the new list, or nil when the text is blank or the list is full.
function QuickReplies.Add(saved, text)
  local trimmed = TextLimits.Trim(text)
  if trimmed == nil or not QuickReplies.CanAdd(saved) then
    return nil
  end
  local list = copyList(saved)
  -- A longer reply could never be sent as one whisper.
  list[#list + 1] = TextLimits.CapBytes(trimmed, TextLimits.MESSAGE_MAX_BYTES)
  return list
end

function QuickReplies.Remove(saved, index)
  local list = copyList(saved)
  table.remove(list, index)
  return list
end

ns.QuickReplies = QuickReplies
return QuickReplies
