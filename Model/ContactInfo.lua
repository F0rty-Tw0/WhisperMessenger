local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

-- One-line notes other addons attach to a player, shown in the conversation
-- pane's info strip. State is { [canonicalName] = { [sourceKey] = text } };
-- a note for a player with no conversation yet waits until one exists. A chat
-- shows at most one line per source: the names that resolve to one chat
-- ("Jaina", "Jaina-Proudmoore") share it.
local ContactInfo = {}

ContactInfo.MAX_PLAYERS = 200
ContactInfo.MAX_SOURCES = 10

local function isNonEmptyString(value)
  return type(value) == "string" and value ~= ""
end

function ContactInfo.New()
  return {}
end

local function countKeys(map)
  local count = 0
  for _ in pairs(map) do
    count = count + 1
  end
  return count
end

local function removeNote(state, canonicalName, sourceKey)
  local notes = state[canonicalName]
  if notes == nil then
    return
  end
  notes[sourceKey] = nil
  if next(notes) == nil then
    state[canonicalName] = nil
  end
end

-- The stored names that resolve to the chat, the full name first: the chat's
-- own name and its name without the realm. Anything else cannot resolve to it.
local function namesForChat(runtime, conversationKey)
  local conversations = runtime and runtime.store and runtime.store.conversations
  local conversation = type(conversations) == "table" and conversations[conversationKey] or nil
  local displayName = type(conversation) == "table" and (conversation.displayName or conversation.contactDisplayName) or nil
  if type(displayName) ~= "string" then
    return {}
  end
  local fullName = Identity.FromWhisper(displayName).canonicalName
  local baseName = string.match(fullName, "^([^%-]+)")
  local names = {}
  for _, name in ipairs({ fullName, baseName or fullName }) do
    if names[1] ~= name and Identity.ResolveWhisperConversation(runtime, name, "WOW") == conversationKey then
      names[#names + 1] = name
    end
  end
  return names
end

-- True when the player's name resolves to that conversation.
function ContactInfo.ResolvesTo(runtime, playerName, conversationKey)
  if conversationKey == nil or not isNonEmptyString(playerName) then
    return false
  end
  local canonicalName = Identity.FromWhisper(playerName).canonicalName
  return Identity.ResolveWhisperConversation(runtime, canonicalName, "WOW") == conversationKey
end

-- text nil, or blank, removes the note; longer text is cut to the chat limit.
-- With runtime, the source's note replaces (or removes) its note under the
-- other names of the same chat. False on bad arguments or past a cap.
function ContactInfo.Set(state, sourceKey, playerName, text, runtime)
  if not isNonEmptyString(sourceKey) or not isNonEmptyString(playerName) then
    return false
  end
  if text ~= nil and type(text) ~= "string" then
    return false
  end

  local canonicalName = Identity.FromWhisper(playerName).canonicalName
  local notes = state[canonicalName]
  local note = text ~= nil and TextLimits.Trim(text) or nil
  if note ~= nil then
    if notes == nil and countKeys(state) >= ContactInfo.MAX_PLAYERS then
      return false
    end
    if notes ~= nil and notes[sourceKey] == nil and countKeys(notes) >= ContactInfo.MAX_SOURCES then
      return false
    end
  end

  local chatKey = runtime and Identity.ResolveWhisperConversation(runtime, canonicalName, "WOW")
  if chatKey then
    for _, name in ipairs(namesForChat(runtime, chatKey)) do
      removeNote(state, name, sourceKey)
    end
  end
  removeNote(state, canonicalName, sourceKey)
  if note == nil then
    return true
  end
  notes = state[canonicalName] or {}
  state[canonicalName] = notes
  notes[sourceKey] = TextLimits.CapBytes(note, TextLimits.MESSAGE_MAX_BYTES)
  return true
end

-- The note texts for the selected contact, ordered by source key.
function ContactInfo.LinesFor(runtime, selectedContact)
  local state = runtime and runtime.contactInfo
  local conversationKey = selectedContact and selectedContact.conversationKey
  if state == nil or conversationKey == nil then
    return {}
  end

  local bySource = {}
  local sourceKeys = {}
  for _, name in ipairs(namesForChat(runtime, conversationKey)) do
    for sourceKey, text in pairs(state[name] or {}) do
      if bySource[sourceKey] == nil then
        bySource[sourceKey] = text
        sourceKeys[#sourceKeys + 1] = sourceKey
      end
    end
  end
  table.sort(sourceKeys)

  local lines = {}
  for index, sourceKey in ipairs(sourceKeys) do
    lines[index] = bySource[sourceKey]
  end
  return lines
end

ns.ContactInfo = ContactInfo
return ContactInfo
