local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Keyword rules: plain, case-insensitive words. A rule matches a line only
-- when every one of its words appears; a word written "a/b" is satisfied by
-- any one of its alternatives. An alternative in double quotes only matches
-- as a whole word ("anal" skips "canal"); a quoted phrase ("gold seller") is
-- one such word. Letters are ASCII letters, digits and any non-ASCII byte,
-- so Cyrillic and CJK words keep their edges. Words are lowercased on save,
-- so matching never lowers them again.
local KeywordRules = {}

local find = string.find
local gmatch = string.gmatch
local gsub = string.gsub
local sub = string.sub
local ipairs = ipairs

local WORD_SEPARATOR = " + "
-- Stands in for spaces inside a quoted phrase while the text is split.
local PHRASE_SPACE = ""

-- Quotes pair up left to right, so an odd one out is the last.
local function dropUnpairedQuote(text)
  local _, quotes = gsub(text, '"', "")
  if quotes % 2 == 1 then
    text = gsub(text, '^(.*)"', "%1")
  end
  return text
end

local function joinPhrase(quoted)
  return (gsub(quoted, "%s+", PHRASE_SPACE))
end

-- A lone "+" only separates words, so formatted rules parse back unchanged.
-- A quoted phrase ("gold seller") stays one whole-word word.
local function parseWords(wordsText)
  if type(wordsText) ~= "string" then
    return nil
  end
  local text = gsub(dropUnpairedQuote(string.lower(wordsText)), '"[^"]*"', joinPhrase)
  local words = {}
  for word in gmatch(text, "%S+") do
    if word ~= "+" then
      words[#words + 1] = (gsub(word, PHRASE_SPACE, " "))
    end
  end
  if #words == 0 then
    return nil
  end
  return words
end

function KeywordRules.Add(filters, wordsText)
  local words = parseWords(wordsText)
  if words == nil then
    return nil
  end
  local rule = { words = words, enabled = true, blocked = 0 }
  filters.rules[#filters.rules + 1] = rule
  return rule
end

-- Replaces a rule's words; its name, state and blocked count stay.
function KeywordRules.SetWords(filters, index, wordsText)
  local rule = filters.rules[index]
  local words = parseWords(wordsText)
  if rule == nil or words == nil then
    return nil
  end
  rule.words = words
  return rule
end

function KeywordRules.Format(rule)
  return table.concat(rule.words, WORD_SEPARATOR)
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

local LETTERS = "%w\128-\255"
local LETTER = "^[" .. LETTERS .. "]$"
local WORD_START = "%f[" .. LETTERS .. "]"
local WORD_END = "%f[^" .. LETTERS .. "]"

-- Edges are only required where the word itself starts or ends with a
-- letter, so "m+" still matches before a space.
local function wholeWordPattern(inner)
  local pattern = gsub(inner, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  if find(sub(inner, 1, 1), LETTER) then
    pattern = WORD_START .. pattern
  end
  if find(sub(inner, -1), LETTER) then
    pattern = pattern .. WORD_END
  end
  return pattern
end

local function parseAlternative(alternative)
  local inner = string.match(alternative, '^"(.+)"$')
  if inner then
    return { pattern = wholeWordPattern(inner) }
  end
  return { text = alternative }
end

-- Split once per distinct word; saved words are few and rarely change.
local alternativesByWord = {}

local function alternativesOf(word)
  local alternatives = alternativesByWord[word]
  if alternatives == nil then
    alternatives = {}
    for alternative in gmatch(word, "[^/]+") do
      alternatives[#alternatives + 1] = parseAlternative(alternative)
    end
    alternativesByWord[word] = alternatives
  end
  return alternatives
end

local function matchesAny(word, lowerText)
  for _, alternative in ipairs(alternativesOf(word)) do
    if alternative.pattern then
      if find(lowerText, alternative.pattern) then
        return true
      end
    elseif find(lowerText, alternative.text, 1, true) then
      return true
    end
  end
  return false
end

-- A damaged saved rule (no words, or words that are not text) matches
-- nothing, so it never hides a line.
local function matchesAll(words, lowerText)
  if type(words) ~= "table" or words[1] == nil then
    return false
  end
  for _, word in ipairs(words) do
    if type(word) ~= "string" or not matchesAny(word, lowerText) then
      return false
    end
  end
  return true
end

-- Whether a rule applies to a line kind ("group", "channel"). A rule without
-- a scope applies to every kind; a scoped one (the ready-made rules) only to
-- its own. A nil kind skips the check.
local function inScope(rule, kind)
  return kind == nil or rule.scope == nil or rule.scope == kind
end

-- First enabled in-scope rule whose words all appear in the
-- already-lowercased text.
function KeywordRules.Match(filters, lowerText, kind)
  for _, rule in ipairs(filters.rules) do
    if rule.enabled and inScope(rule, kind) and matchesAll(rule.words, lowerText) then
      return rule
    end
  end
  return nil
end

ns.KeywordRules = KeywordRules
return KeywordRules
