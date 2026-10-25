local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")

-- One-line notes other addons attach to a player, shown in the conversation
-- pane's info strip. State is { [canonicalName] = { [sourceKey] = text } };
-- a note for a player with no conversation yet waits until one exists.
local ContactInfo = {}

local function isNonEmptyString(value)
  return type(value) == "string" and value ~= ""
end

function ContactInfo.New()
  return {}
end

-- text nil removes the note. Returns false on bad arguments.
function ContactInfo.Set(state, sourceKey, playerName, text)
  if not isNonEmptyString(sourceKey) or not isNonEmptyString(playerName) then
    return false
  end
  if text ~= nil and type(text) ~= "string" then
    return false
  end

  local canonicalName = Identity.FromWhisper(playerName).canonicalName
  local notes = state[canonicalName]
  if text == nil then
    if notes then
      notes[sourceKey] = nil
      if next(notes) == nil then
        state[canonicalName] = nil
      end
    end
    return true
  end
  if notes == nil then
    notes = {}
    state[canonicalName] = notes
  end
  notes[sourceKey] = text
  return true
end

-- The note texts for the selected contact, ordered by source key.
function ContactInfo.LinesFor(runtime, selectedContact)
  local state = runtime and runtime.contactInfo
  local conversationKey = selectedContact and selectedContact.conversationKey
  if state == nil or conversationKey == nil then
    return {}
  end

  local entries = {}
  for canonicalName, notes in pairs(state) do
    if Identity.ResolveWhisperConversation(runtime, canonicalName, "WOW") == conversationKey then
      for sourceKey, text in pairs(notes) do
        entries[#entries + 1] = { key = sourceKey, text = text }
      end
    end
  end
  table.sort(entries, function(a, b)
    if a.key ~= b.key then
      return a.key < b.key
    end
    return a.text < b.text
  end)

  local lines = {}
  for index, entry in ipairs(entries) do
    lines[index] = entry.text
  end
  return lines
end

ns.ContactInfo = ContactInfo
return ContactInfo
