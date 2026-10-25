local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

-- One-line notes other addons attach to a player, shown in the conversation
-- pane's info strip. State is { [canonicalName] = { [sourceKey] = note } },
-- note = { text, tooltip? }; a note for a player with no conversation yet
-- waits until one exists. A chat
-- shows at most one line per source: the names that resolve to one chat
-- ("Jaina", "Jaina-Proudmoore") share it.
local ContactInfo = {}

ContactInfo.MAX_PLAYERS = 200
ContactInfo.MAX_SOURCES = 10
ContactInfo.MAX_TOOLTIP_LINES = 10

local function isNonEmptyString(value)
  return type(value) == "string" and value ~= ""
end

-- nil, or an array of 1..MAX_TOOLTIP_LINES non-empty strings with no holes.
local function isValidTooltip(lines)
  if lines == nil then
    return true
  end
  if type(lines) ~= "table" then
    return false
  end
  local count = 0
  for _, line in pairs(lines) do
    if not isNonEmptyString(line) then
      return false
    end
    count = count + 1
    -- Stop at the first line over the cap: a huge table is not walked in full.
    if count > ContactInfo.MAX_TOOLTIP_LINES then
      return false
    end
  end
  if count < 1 then
    return false
  end
  -- count keys that are exactly 1..count: any other key leaves a gap here.
  for index = 1, count do
    if lines[index] == nil then
      return false
    end
  end
  return true
end

-- The state keeps this copy: a caller that changes its table later changes
-- nothing. Each line is cut to the chat limit, like the note.
local function copyTooltip(lines)
  if lines == nil then
    return nil
  end
  local copy = {}
  for index, line in ipairs(lines) do
    copy[index] = TextLimits.CapBytes(line, TextLimits.MESSAGE_MAX_BYTES)
  end
  return copy
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

-- text nil, or blank, removes the note and its tooltip; longer text is cut to
-- the chat limit. tooltipLines (optional) are the lines shown on hover; text
-- without them clears the source's old tooltip. With runtime, the source's
-- note replaces (or removes) its note under the other names of the same chat.
-- False, with nothing changed, on bad arguments or past a cap.
function ContactInfo.Set(state, sourceKey, playerName, text, runtime, tooltipLines)
  if not isNonEmptyString(sourceKey) or not isNonEmptyString(playerName) then
    return false
  end
  if text ~= nil and type(text) ~= "string" then
    return false
  end
  if not isValidTooltip(tooltipLines) then
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
  notes[sourceKey] = { text = TextLimits.CapBytes(note, TextLimits.MESSAGE_MAX_BYTES), tooltip = copyTooltip(tooltipLines) }
  return true
end

-- The note texts for the selected contact, ordered by source key, and a
-- second table with each line's tooltip lines at the same index (nil: none).
function ContactInfo.LinesFor(runtime, selectedContact)
  local state = runtime and runtime.contactInfo
  local conversationKey = selectedContact and selectedContact.conversationKey
  if state == nil or conversationKey == nil then
    return {}, {}
  end

  local bySource = {}
  local sourceKeys = {}
  for _, name in ipairs(namesForChat(runtime, conversationKey)) do
    for sourceKey, note in pairs(state[name] or {}) do
      if bySource[sourceKey] == nil then
        bySource[sourceKey] = note
        sourceKeys[#sourceKeys + 1] = sourceKey
      end
    end
  end
  table.sort(sourceKeys)

  local lines = {}
  local tooltips = {}
  for index, sourceKey in ipairs(sourceKeys) do
    lines[index] = bySource[sourceKey].text
    tooltips[index] = bySource[sourceKey].tooltip
  end
  return lines, tooltips
end

ns.ContactInfo = ContactInfo
return ContactInfo
