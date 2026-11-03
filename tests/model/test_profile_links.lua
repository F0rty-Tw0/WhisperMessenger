local ProfileLinks = require("WhisperMessenger.Model.ProfileLinks")

-- Profile site links for one character, per game flavor and region.

local RETAIL = 1
local CLASSIC_ERA = 2
local TBC_ANNIVERSARY = 5
local MISTS_CLASSIC = 19
local US = 1
local EU = 3
local CN = 5

local function urlsByLabel(links)
  local byLabel = {}
  for _, link in ipairs(links) do
    byLabel[link.label] = link.url
  end
  return byLabel
end

local function count(links)
  return #links
end

return function()
  local arthas = { name = "Arthas", realm = "Area52", displayRealm = "Area 52" }

  -- test_retail_offers_raiderio_warcraftlogs_and_armory_in_order
  do
    local links = ProfileLinks.Build(arthas, { regionId = US, projectId = RETAIL })
    assert(count(links) == 3, "three retail sites, got " .. count(links))
    assert(links[1].label == "Raider.IO", "Raider.IO first, got " .. tostring(links[1].label))
    assert(links[2].label == "Warcraft Logs", "Warcraft Logs second, got " .. tostring(links[2].label))
    assert(links[3].label == "Armory", "Armory third, got " .. tostring(links[3].label))
  end

  -- test_retail_raiderio_url
  do
    local urls = urlsByLabel(ProfileLinks.Build(arthas, { regionId = EU, projectId = RETAIL }))
    assert(urls["Raider.IO"] == "https://raider.io/characters/eu/area-52/Arthas", "raider.io url, got " .. tostring(urls["Raider.IO"]))
  end

  -- test_retail_warcraftlogs_url
  do
    local urls = urlsByLabel(ProfileLinks.Build(arthas, { regionId = US, projectId = RETAIL }))
    local expected = "https://www.warcraftlogs.com/character/us/area-52/arthas"
    assert(urls["Warcraft Logs"] == expected, "warcraft logs url, got " .. tostring(urls["Warcraft Logs"]))
  end

  -- test_retail_armory_url
  do
    local urls = urlsByLabel(ProfileLinks.Build(arthas, { regionId = US, projectId = RETAIL }))
    local expected = "https://worldofwarcraft.blizzard.com/en-us/character/us/area-52/arthas"
    assert(urls["Armory"] == expected, "armory url, got " .. tostring(urls["Armory"]))
  end

  -- test_armory_left_out_when_realm_slug_is_a_guess
  do
    local links = ProfileLinks.Build({ name = "Arthas", realm = "ArgentDawn" }, { regionId = EU, projectId = RETAIL })
    local urls = urlsByLabel(links)
    assert(urls["Armory"] == nil, "no armory link without the realm's display name")
    assert(
      urls["Raider.IO"] == "https://raider.io/characters/eu/argentdawn/Arthas",
      "raider.io takes the bare slug, got " .. tostring(urls["Raider.IO"])
    )
  end

  -- test_armory_kept_for_a_one_word_realm
  do
    local urls = urlsByLabel(ProfileLinks.Build({ name = "Thrall", realm = "Kazzak" }, { regionId = EU, projectId = RETAIL }))
    local expected = "https://worldofwarcraft.blizzard.com/en-us/character/eu/kazzak/thrall"
    assert(urls["Armory"] == expected, "one-word realm keeps armory, got " .. tostring(urls["Armory"]))
  end

  -- test_classic_era_offers_vanilla_warcraftlogs_only
  do
    local links = ProfileLinks.Build(arthas, { regionId = US, projectId = CLASSIC_ERA })
    assert(count(links) == 1, "era: one site, got " .. count(links))
    assert(links[1].url == "https://vanilla.warcraftlogs.com/character/us/area-52/arthas", "era url, got " .. tostring(links[1].url))
  end

  -- test_tbc_anniversary_uses_fresh_warcraftlogs
  do
    local links = ProfileLinks.Build(arthas, { regionId = US, projectId = TBC_ANNIVERSARY })
    assert(count(links) == 1, "tbc: one site, got " .. count(links))
    assert(links[1].url == "https://fresh.warcraftlogs.com/character/us/area-52/arthas", "tbc url, got " .. tostring(links[1].url))
  end

  -- test_mists_classic_uses_classic_warcraftlogs
  do
    local links = ProfileLinks.Build(arthas, { regionId = EU, projectId = MISTS_CLASSIC })
    assert(count(links) == 1, "mists: one site, got " .. count(links))
    assert(links[1].url == "https://classic.warcraftlogs.com/character/eu/area-52/arthas", "mists url, got " .. tostring(links[1].url))
  end

  -- test_china_region_has_no_links
  do
    assert(count(ProfileLinks.Build(arthas, { regionId = CN, projectId = RETAIL })) == 0, "no sites for China")
  end

  -- test_unknown_region_has_no_links
  do
    assert(count(ProfileLinks.Build(arthas, { regionId = nil, projectId = RETAIL })) == 0, "no sites without a region")
  end

  -- test_forever_has_no_links
  do
    assert(count(ProfileLinks.Build(arthas, { regionId = US, projectId = RETAIL, isForever = true })) == 0, "no sites on WoW: Forever")
  end

  -- test_non_latin_realm_has_no_links
  do
    local links = ProfileLinks.Build(
      { name = "Thrall", realm = "Гордунни", displayRealm = "Гордунни" },
      { regionId = EU, projectId = RETAIL }
    )
    assert(count(links) == 0, "no sites for a realm without an ASCII slug, got " .. count(links))
  end

  -- test_accented_name_is_url_encoded
  do
    local urls = urlsByLabel(ProfileLinks.Build({ name = "Ellesmére", realm = "EmeraldDream", displayRealm = "Emerald Dream" }, {
      regionId = US,
      projectId = RETAIL,
    }))
    local expected = "https://raider.io/characters/us/emerald-dream/Ellesm%C3%A9re"
    assert(urls["Raider.IO"] == expected, "accented name encoded, got " .. tostring(urls["Raider.IO"]))
  end
end
