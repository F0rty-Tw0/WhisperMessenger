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

local function containsTerm(value, term)
  return type(value) == "string" and string.find(string.lower(value), term, 1, true) ~= nil
end

local function itemMatchesSearch(item, terms)
  if #terms == 0 then
    return true
  end
  if type(item) ~= "table" then
    return false
  end

  local unmatched = {}
  local remaining = #terms
  for index in ipairs(terms) do
    unmatched[index] = true
  end

  local function match(value)
    for index, term in ipairs(terms) do
      if unmatched[index] and containsTerm(value, term) then
        unmatched[index] = nil
        remaining = remaining - 1
      end
    end
  end

  match(item.displayName)
  match(item.contactDisplayName)
  match(item.conversationKey)
  match(item.battleTag)
  match(item.gameAccountName)
  match(item.className)
  match(item.raceName)
  match(item.factionName)
  match(item.lastPreview)
  if remaining == 0 then
    return true
  end

  for _, message in ipairs((item.conversation or {}).messages or {}) do
    if type(message) == "table" then
      match(message.text)
      match(message.playerName)
      if remaining == 0 then
        return true
      end
    end
  end

  return false
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

function ContactSearch.BuildVisibleContacts(items, normalizedQuery)
  local visible = {}
  local terms = buildSearchTerms(normalizedQuery)
  for _, item in ipairs(items or {}) do
    if itemMatchesSearch(item, terms) then
      visible[#visible + 1] = item
    end
  end
  return visible
end

ns.MessengerWindowContactSearch = ContactSearch

return ContactSearch
