local KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules")

-- An own rule can carry a title; without one the list shows its words.
local function newFilters()
  return { ignored = {}, rules = {} }
end

return function()
  -- test_add_saves_the_trimmed_name
  do
    local rule = assert(KeywordRules.Add(newFilters(), "wts boost", "  Boost sellers  "))
    assert(rule.name == "Boost sellers", "name saved trimmed, got " .. tostring(rule.name))
  end

  -- test_add_with_a_blank_name_saves_none
  do
    local rule = assert(KeywordRules.Add(newFilters(), "wts boost", "   "))
    assert(rule.name == nil, "blank name falls back to the words")
  end

  -- test_set_name_renames_an_own_rule
  do
    local filters = newFilters()
    KeywordRules.Add(filters, "wts boost", "Old")
    local rule = assert(KeywordRules.SetName(filters, 1, " New "))
    assert(rule.name == "New", "renamed, got " .. tostring(rule.name))
  end

  -- test_set_name_blank_clears_the_name
  do
    local filters = newFilters()
    KeywordRules.Add(filters, "wts boost", "Old")
    KeywordRules.SetName(filters, 1, "")
    assert(filters.rules[1].name == nil, "a blank name clears it")
  end

  -- test_set_name_leaves_ready_made_rules_alone
  do
    local filters = { ignored = {}, rules = { { presetId = "wtsWtb", name = "WTS / WTB / LFW", words = { "wts" }, enabled = true } } }
    assert(KeywordRules.SetName(filters, 1, "Mine") == nil, "a ready-made title is fixed")
    assert(filters.rules[1].name == "WTS / WTB / LFW", "name kept")
  end
end
