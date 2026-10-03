local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Ready-made keyword rules, adapted from Global Ignore List's default spam
-- filters (GlobalIgnoreList.lua, 2026-08). Each is seeded once per account as
-- an ordinary rule the player can edit, switch off or remove; ids recorded in
-- `filters.seededPresets` keep a removed preset from coming back. Words are
-- lowercase. "|H<type>:" link codes match as "h<type>:" because rule text
-- never contains "|", WoW's escape character. GIL's non-Latin and politics
-- filters need whole-word or script matching and are left out. Presets only
-- filter channels (scope "channel"): guild, party and raid lines are people
-- the player plays with, not spam.
local RulePresets = {}

local ipairs = ipairs

local SCOPE = "channel"

local ANY_LINK = "hitem:/hspell:/hachievement:/hmount:/hbattlepet:/hjournal:/hquest:"

-- Ids are saved; never rename or reuse one. Names are English locale keys.
RulePresets.LIST = {
  { id = "analSpam", name = '"Anal" link spam', words = { '"anal"/analan', ANY_LINK }, enabled = true },
  { id = "thunderfury", name = "Thunderfury links", words = { "hitem:19019:" }, enabled = true },
  {
    id = "mythicSellers",
    name = "Mythic+ and raid sellers",
    words = {
      "wts/sell/offer/cheap/starting",
      "m+/boost/carry/raid/mythic/keys/afk/hachievement:/hjournal:",
    },
  },
  {
    id = "professionSellers",
    name = "Profession sellers",
    words = { "lfw/trade/order/tip/%/max/free/craft/mats/pay", "htrade:/hitem:" },
  },
  {
    id = "powerLeveling",
    name = "Power-leveling sellers",
    words = { "wts/service/sell/fast/afk", "power/pwr", "level/lvl" },
  },
  { id = "guildRecruitment", name = "Guild recruitment", words = { "guild/</hclubfinder:", "recruit/progress/seek" } },
  { id = "communityRecruitment", name = "Community recruitment", words = { "hclubfinder:" } },
  { id = "wtsWtb", name = "WTS / WTB", words = { "wts/wtb" } },
}

local function copyWords(words)
  local copy = {}
  for index, word in ipairs(words) do
    copy[index] = word
  end
  return copy
end

function RulePresets.Seed(filters)
  local seededIds = filters.seededPresets
  if type(seededIds) ~= "table" then
    seededIds = {}
    filters.seededPresets = seededIds
  end
  -- Presets saved before scopes existed applied to group lines too.
  for _, rule in ipairs(filters.rules) do
    if type(rule) == "table" and rule.presetId ~= nil and rule.scope == nil then
      rule.scope = SCOPE
    end
  end
  for _, preset in ipairs(RulePresets.LIST) do
    if not seededIds[preset.id] then
      filters.rules[#filters.rules + 1] = {
        presetId = preset.id,
        name = preset.name,
        scope = SCOPE,
        words = copyWords(preset.words),
        enabled = preset.enabled == true,
        blocked = 0,
      }
      seededIds[preset.id] = true
    end
  end
end

-- Back to a fresh install: the player's own rules go, every preset returns
-- with its original words, state and a zero count. Lists are cleared in place
-- because the Filters page and the chat filter hold them.
function RulePresets.Reset(filters)
  for index = #filters.rules, 1, -1 do
    filters.rules[index] = nil
  end
  if type(filters.seededPresets) == "table" then
    for id in pairs(filters.seededPresets) do
      filters.seededPresets[id] = nil
    end
  end
  RulePresets.Seed(filters)
end

ns.RulePresets = RulePresets
return RulePresets
