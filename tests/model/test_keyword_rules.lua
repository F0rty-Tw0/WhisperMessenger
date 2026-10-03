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

  -- test_slash_word_matches_any_alternative
  do
    local filters = newFilters()
    local rule = assert(KeywordRules.Add(filters, "WTS/sell boost/carry"))
    assert(KeywordRules.Match(filters, "sell mythic carry") == rule, "one alternative from each group matches")
    assert(KeywordRules.Match(filters, "wts boost") == rule, "the first alternatives match too")
    assert(KeywordRules.Match(filters, "sell gold") == nil, "a group with no alternative present fails")
  end

  -- test_add_ignores_bare_plus_between_words
  do
    local filters = newFilters()
    local rule = assert(KeywordRules.Add(filters, "wts/sell + m+"))
    assert(#rule.words == 2 and rule.words[1] == "wts/sell" and rule.words[2] == "m+", "a lone + only separates")
  end

  -- test_format_round_trips_through_add
  do
    local filters = newFilters()
    local rule = assert(KeywordRules.Add(filters, "wts/sell boost"))
    local text = KeywordRules.Format(rule)
    assert(text == "wts/sell + boost", "groups joined with +, got " .. text)
    local again = assert(KeywordRules.Add(filters, text))
    assert(again.words[1] == "wts/sell" and again.words[2] == "boost", "formatted text parses back")
  end

  -- test_set_words_replaces_words_and_keeps_the_rest
  do
    local filters = newFilters()
    local rule = assert(KeywordRules.Add(filters, "wts"))
    rule.blocked, rule.name, rule.enabled = 4, "WTS / WTB", false
    assert(KeywordRules.SetWords(filters, 1, "WTS/wtb") == rule, "edits the rule in place")
    assert(#rule.words == 1 and rule.words[1] == "wts/wtb", "words replaced and lowercased")
    assert(rule.blocked == 4 and rule.name == "WTS / WTB" and rule.enabled == false, "count, name and state kept")
    assert(KeywordRules.SetWords(filters, 1, "  ") == nil, "blank text is refused")
    assert(rule.words[1] == "wts/wtb", "a refused edit keeps the old words")
  end

  -- test_quoted_word_matches_whole_words_only
  do
    local filters = newFilters()
    assert(KeywordRules.Add(filters, '"anal"'))
    assert(KeywordRules.Match(filters, "anal [thunderfury]") ~= nil, "the word on its own matches")
    assert(KeywordRules.Match(filters, "lol anal!") ~= nil, "punctuation ends a word")
    assert(KeywordRules.Match(filters, "the canal") == nil, "a longer word containing it does not match")
    assert(KeywordRules.Match(filters, "analysis done") == nil, "a word starting with it does not match")
  end

  -- test_quoted_alternative_mixes_with_plain_ones
  do
    local filters = newFilters()
    assert(KeywordRules.Add(filters, '"anal"/analan'))
    assert(KeywordRules.Match(filters, "analanalanal") ~= nil, "the plain alternative still matches inside words")
    assert(KeywordRules.Match(filters, "canal") == nil, "the quoted alternative stays whole-word")
  end

  -- test_quoted_word_respects_non_latin_letters
  -- Lowered like the chat filter does; some C locales change high bytes.
  do
    local filters = newFilters()
    assert(KeywordRules.Add(filters, '"привет"'))
    assert(KeywordRules.Match(filters, string.lower("привет всем")) ~= nil, "a whole Cyrillic word matches")
    assert(KeywordRules.Match(filters, string.lower("приветствую")) == nil, "a longer Cyrillic word does not")
  end

  -- test_quoted_word_treats_pattern_characters_literally
  do
    local filters = newFilters()
    assert(KeywordRules.Add(filters, '"m+"'))
    assert(KeywordRules.Match(filters, "selling m+ runs") ~= nil, "plus is literal")
    assert(KeywordRules.Match(filters, "selling mm runs") == nil, "plus is not a repeat")
  end
end
