local KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules")

local function newFilters()
  return { ignored = {}, rules = {} }
end

return function()
  -- test_add_stores_lowercased_words_enabled_with_zero_blocked
  do
    local filters = newFilters()
    local rule = assert(KeywordRules.Add(filters, "WTS boost"))
    assert(filters.rules[1] == rule, "rule is appended to the list")
    assert(#rule.words == 2 and rule.words[1] == "wts" and rule.words[2] == "boost", "words are split and lowercased")
    assert(rule.enabled == true, "new rule is enabled")
    assert(rule.blocked == 0, "new rule has blocked nothing")
  end

  -- test_match_requires_every_word
  do
    local filters = newFilters()
    local rule = KeywordRules.Add(filters, "WTS boost")
    assert(KeywordRules.Match(filters, "wts mythic boost cheap") == rule, "all words present matches")
    assert(KeywordRules.Match(filters, "wts mats") == nil, "a missing word does not match")
  end

  -- test_disabled_rule_never_matches
  do
    local filters = newFilters()
    KeywordRules.Add(filters, "boost")
    KeywordRules.SetEnabled(filters, 1, false)
    assert(KeywordRules.Match(filters, "cheap boost") == nil, "disabled rule is skipped")
    KeywordRules.SetEnabled(filters, 1, true)
    assert(KeywordRules.Match(filters, "cheap boost") ~= nil, "re-enabled rule matches")
  end

  -- test_match_treats_words_literally
  do
    local filters = newFilters()
    KeywordRules.Add(filters, "%d+")
    assert(KeywordRules.Match(filters, "selling 100 gold") == nil, "pattern characters are not a Lua pattern")
    assert(KeywordRules.Match(filters, "literal %d+ here") ~= nil, "pattern characters match literally")
  end

  -- test_add_blank_returns_nil
  do
    local filters = newFilters()
    assert(KeywordRules.Add(filters, "   ") == nil, "blank text makes no rule")
    assert(#filters.rules == 0, "nothing is stored")
  end

  -- test_remove_drops_rule_by_index
  do
    local filters = newFilters()
    KeywordRules.Add(filters, "one")
    local second = KeywordRules.Add(filters, "two")
    KeywordRules.Remove(filters, 1)
    assert(#filters.rules == 1 and filters.rules[1] == second, "remaining rule shifts down")
  end
end
