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

local function itemMatchesSearch(item, terms)
  if #terms == 0 then
    return true
  end
  if type(item) ~= "table" then
    return false
  end

  local haystack = item.searchText or item.displayName or ""
  if haystack == "" then
    return false
  end

  local loweredHaystack = string.lower(haystack)
  for _, term in ipairs(terms) do
    if string.find(loweredHaystack, term, 1, true) == nil then
      return false
    end
  end
  return true
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
