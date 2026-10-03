local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Keyword rules: plain, case-insensitive words. A rule matches a line only
-- when every one of its words appears. Words are lowercased on save, so
-- matching never lowers them again.
local KeywordRules = {}

local find = string.find
local ipairs = ipairs

function KeywordRules.Add(filters, wordsText)
  if type(wordsText) ~= "string" then
    return nil
  end
  local words = {}
  for word in string.gmatch(string.lower(wordsText), "%S+") do
    words[#words + 1] = word
  end
  if #words == 0 then
    return nil
  end
  local rule = { words = words, enabled = true, blocked = 0 }
  filters.rules[#filters.rules + 1] = rule
  return rule
end

function KeywordRules.Remove(filters, index)
  table.remove(filters.rules, index)
end

function KeywordRules.SetEnabled(filters, index, enabled)
  local rule = filters.rules[index]
  if rule then
    rule.enabled = enabled and true or false
  end
end

local function matchesAll(words, lowerText)
  for _, word in ipairs(words) do
    if not find(lowerText, word, 1, true) then
      return false
    end
  end
  return true
end

-- First enabled rule whose words all appear in the already-lowercased text.
function KeywordRules.Match(filters, lowerText)
  for _, rule in ipairs(filters.rules) do
    if rule.enabled and matchesAll(rule.words, lowerText) then
      return rule
    end
  end
  return nil
end

ns.KeywordRules = KeywordRules
return KeywordRules
