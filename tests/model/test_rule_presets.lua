local RulePresets = require("WhisperMessenger.Model.Filters.RulePresets")
local KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules")

local THUNDERFURY = "|cffff8000|Hitem:19019::::::::80:::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r"

local function seeded()
  local filters = { ignored = {}, rules = {} }
  RulePresets.Seed(filters)
  return filters
end

local function ruleById(filters, id)
  for index, rule in ipairs(filters.rules) do
    if rule.presetId == id then
      return rule, index
    end
  end
  return nil
end

-- Only this rule enabled, so Match answers for it alone.
local function matchesOnly(filters, id, line)
  for _, rule in ipairs(filters.rules) do
    rule.enabled = rule.presetId == id
  end
  return KeywordRules.Match(filters, string.lower(line)) ~= nil
end

return function()
  -- test_seed_adds_every_preset_as_a_named_rule
  do
    local filters = seeded()
    assert(#filters.rules == #RulePresets.LIST, "one rule per preset")
    for index, preset in ipairs(RulePresets.LIST) do
      local rule = filters.rules[index]
      assert(rule.presetId == preset.id and rule.name == preset.name, "rule carries the preset id and name")
      assert(rule.blocked == 0, "starts with nothing blocked")
      assert(rule.words ~= preset.words, "rule gets its own copy of the words")
    end
  end

  -- test_seed_runs_once_per_preset
  do
    local filters = seeded()
    local count = #filters.rules
    RulePresets.Seed(filters)
    assert(#filters.rules == count, "a second load adds nothing")
  end

  -- test_removed_preset_stays_removed
  do
    local filters = seeded()
    local _, index = ruleById(filters, "wtsWtb")
    KeywordRules.Remove(filters, index)
    RulePresets.Seed(filters)
    assert(ruleById(filters, "wtsWtb") == nil, "removed preset is not seeded again")
  end

  -- test_seed_keeps_player_rules_first
  do
    local filters = { ignored = {}, rules = {} }
    local own = KeywordRules.Add(filters, "gold")
    RulePresets.Seed(filters)
    assert(filters.rules[1] == own, "existing rules keep their place")
  end

  -- test_only_link_spam_presets_start_on
  do
    local filters = seeded()
    assert(ruleById(filters, "analSpam").enabled == true, "anal spam on, like Global Ignore List")
    assert(ruleById(filters, "thunderfury").enabled == true, "Thunderfury on, like Global Ignore List")
    assert(ruleById(filters, "wtsWtb").enabled == false, "sellers and recruiting start off")
  end

  -- test_presets_catch_their_spam
  do
    local filters = seeded()
    assert(matchesOnly(filters, "thunderfury", "Did someone say " .. THUNDERFURY), "Thunderfury link")
    assert(matchesOnly(filters, "analSpam", "anal " .. THUNDERFURY), "anal plus a link")
    assert(not matchesOnly(filters, "analSpam", "anal"), "the word alone is not link spam")
    assert(not matchesOnly(filters, "analSpam", "canal " .. THUNDERFURY), "canal is not the word")
    assert(not matchesOnly(filters, "analSpam", "analysis of " .. THUNDERFURY), "analysis is not the word")
    assert(matchesOnly(filters, "mythicSellers", "WTS +10 keys, cheap carry"), "key seller")
    assert(matchesOnly(filters, "powerLeveling", "selling fast power leveling 10-80"), "power leveling seller")
    assert(matchesOnly(filters, "guildRecruitment", "<Raid Team> is recruiting for mythic"), "guild recruitment")
    assert(matchesOnly(filters, "wtsWtb", "WTB [Linen Cloth]"), "WTB")
    assert(matchesOnly(filters, "professionSellers", "Free crafting |Htrade:Player-1:2:3|h[Tailoring]|h"), "profession seller")
    assert(matchesOnly(filters, "communityRecruitment", "Join us |HclubFinder:ClubFinder-1-2|h[Community]|h"), "community link")
    assert(not matchesOnly(filters, "mythicSellers", "LF healer for +10 keys"), "a group ad is not a sale")
  end

  -- test_reset_restores_presets_and_drops_own_rules
  do
    local filters = seeded()
    local rules = filters.rules
    KeywordRules.Remove(filters, 1)
    KeywordRules.SetWords(filters, 1, "edited")
    filters.rules[1].blocked = 9
    KeywordRules.Add(filters, "my own rule")
    RulePresets.Reset(filters)
    assert(filters.rules == rules, "the same list is reset in place")
    assert(#filters.rules == #RulePresets.LIST, "only the presets remain")
    for index, preset in ipairs(RulePresets.LIST) do
      local rule = filters.rules[index]
      assert(rule.presetId == preset.id, "presets back in their original order")
      assert(rule.words[1] == preset.words[1] and rule.blocked == 0, "original words, counter zeroed")
      assert(rule.enabled == (preset.enabled == true), "original on/off state")
    end
  end

  -- test_every_preset_name_is_translated
  do
    for _, code in ipairs({ "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }) do
      local catalog = require("WhisperMessenger.Locale." .. code)
      for _, preset in ipairs(RulePresets.LIST) do
        assert(catalog[preset.name] ~= nil, code .. " has no translation for preset " .. preset.name)
      end
    end
  end
end
