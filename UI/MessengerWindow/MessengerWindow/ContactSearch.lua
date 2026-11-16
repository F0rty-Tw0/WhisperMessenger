local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactSearch = {}

local function buildSearchTerms(normalizedQuery)
  local terms = {}
  for term in string.gmatch(normalizedQuery, "%S+") do
    terms[#terms + 1] = term
  end
  return terms
end

-- Contact fields a search term may match, besides the message history.
local SEARCH_FIELDS = {
  "displayName",
  "nickname",
  "note",
  "contactDisplayName",
  "conversationKey",
  "battleTag",
  "gameAccountName",
  "className",
  "raceName",
  "factionName",
  "lastPreview",
}

local NO_MESSAGES = {}

-- Crosses off every still-unmatched term found in value, lowering value
-- once however many terms are left. Returns how many terms remain.
local function crossOffTerms(value, terms, unmatched, remaining)
  if type(value) ~= "string" then
    return remaining
  end
  local lowered = string.lower(value)
  for index, term in ipairs(terms) do
    if unmatched[index] and string.find(lowered, term, 1, true) then
      unmatched[index] = nil
      remaining = remaining - 1
    end
  end
  return remaining
end

local function messagesOf(item)
  return (item.conversation or NO_MESSAGES).messages or NO_MESSAGES
end

-- Tests the history in order until every term is crossed off. Returns
-- whether that happened and how many messages were read. seen (optional)
-- receives the text and sender of each message read, two slots per message.
local function matchMessages(messages, terms, unmatched, remaining, seen)
  -- Terms only ever get crossed off, so re-checking the previous sender
  -- can't match anything new; skip it to avoid lowering it again.
  local lastPlayerName = nil
  local scanned = 0
  for index, message in ipairs(messages) do
    scanned = index
    local text, playerName = nil, nil
    if type(message) == "table" then
      text, playerName = message.text, message.playerName
      remaining = crossOffTerms(text, terms, unmatched, remaining)
      if playerName ~= lastPlayerName then
        remaining = crossOffTerms(playerName, terms, unmatched, remaining)
        lastPlayerName = playerName
      end
    end
    if seen then
      seen[2 * index - 1] = text or false
      seen[2 * index] = playerName or false
    end
    if remaining == 0 then
      return true, scanned
    end
  end
  return false, scanned
end

-- unmatched is a scratch table shared by one pass. entry (optional) records
-- the answer and every value it came from, see entryIsCurrent.
local function searchItem(item, terms, unmatched, entry)
  local remaining = #terms
  for index = 1, remaining do
    unmatched[index] = true
  end

  for index, field in ipairs(SEARCH_FIELDS) do
    local value = item[field]
    if entry then
      entry.fields[index] = value
    end
    remaining = crossOffTerms(value, terms, unmatched, remaining)
  end

  local matched, scanned = remaining == 0, 0
  if not matched then
    matched, scanned = matchMessages(messagesOf(item), terms, unmatched, remaining, entry and entry.seen)
  end
  if entry then
    entry.matched = matched
    entry.scanned = scanned
  end
  return matched
end

-- True while a cached answer still holds: every contact field and every
-- message the search read is unchanged. Strings compare by identity, so
-- this costs no lowering and no allocation. Checking the values themselves,
-- not a message count, also catches a message edited in place (a long
-- whisper's late part folded into an older message, a censored line
-- revealed), where the count and the last message stay the same.
local function entryIsCurrent(entry, item)
  local fields = entry.fields
  for index, field in ipairs(SEARCH_FIELDS) do
    if fields[index] ~= item[field] then
      return false
    end
  end

  local messages = messagesOf(item)
  local seen = entry.seen
  for index = 1, entry.scanned do
    local message = messages[index]
    if message == nil then
      return false
    end
    local text, playerName = false, false
    if type(message) == "table" then
      text, playerName = message.text or false, message.playerName or false
    end
    if seen[2 * index - 1] ~= text or seen[2 * index] ~= playerName then
      return false
    end
  end

  -- A match stopped at the message that completed it and nothing later can
  -- undo it. A miss read the whole history, so one more message voids it.
  return entry.matched or messages[entry.scanned + 1] == nil
end

local function itemMatchesSearch(item, terms, unmatched, entries, pass)
  if type(item) ~= "table" then
    return false
  end
  local conversationKey = item.conversationKey
  if entries == nil or conversationKey == nil then
    return searchItem(item, terms, unmatched, nil)
  end

  local entry = entries[conversationKey]
  if entry == nil or not entryIsCurrent(entry, item) then
    entry = { fields = {}, seen = {} }
    entries[conversationKey] = entry
    searchItem(item, terms, unmatched, entry)
  end
  entry.pass = pass
  return entry.matched
end

-- Starts a pass over cache: answers for another query are thrown away.
local function beginPass(cache, normalizedQuery)
  if cache.entries == nil or cache.query ~= normalizedQuery then
    cache.query = normalizedQuery
    cache.entries = {}
  end
  cache.pass = (cache.pass or 0) + 1
  return cache.entries, cache.pass
end

-- Drops answers for contacts the pass did not see, such as a deleted one.
local function dropUnseenEntries(entries, pass)
  for conversationKey, entry in pairs(entries) do
    if entry.pass ~= pass then
      entries[conversationKey] = nil
    end
  end
end

function ContactSearch.NormalizeSearchQuery(rawText)
  if type(rawText) ~= "string" then
    return ""
  end

  local normalized = string.lower(rawText)
  normalized = string.gsub(normalized, "^%s+", "")
  normalized = string.gsub(normalized, "%s+$", "")
  return normalized
end

function ContactSearch.IsConversationVisible(items, conversationKey)
  if conversationKey == nil then
    return false
  end

  for _, item in ipairs(items or {}) do
    if item and item.conversationKey == conversationKey then
      return true
    end
  end
  return false
end

-- cache (optional) is a table the caller keeps and passes on every call;
-- start it empty. Contacts whose searched values did not change since the
-- last call with the same query are answered from it instead of having
-- their history searched again. The returned list is the same either way.
function ContactSearch.BuildVisibleContacts(items, normalizedQuery, cache)
  local visible = {}
  local terms = buildSearchTerms(normalizedQuery)
  local entries, pass = nil, nil
  if cache then
    entries, pass = beginPass(cache, normalizedQuery)
  end

  if #terms == 0 then
    for _, item in ipairs(items or {}) do
      visible[#visible + 1] = item
    end
    return visible
  end

  local unmatched = {}
  for _, item in ipairs(items or {}) do
    if itemMatchesSearch(item, terms, unmatched, entries, pass) then
      visible[#visible + 1] = item
    end
  end
  if entries then
    dropUnseenEntries(entries, pass)
  end
  return visible
end

ns.MessengerWindowContactSearch = ContactSearch

return ContactSearch
