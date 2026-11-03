local ProfileLinks = require("WhisperMessenger.Model.ProfileLinks")

-- Classic Era realms log to a Warcraft Logs site per season
-- (C_Seasons.GetActiveSeason, Enum.SeasonID).

local CLASSIC_ERA = 2
local US = 1
local SEASON_OF_MASTERY = 1
local SEASON_OF_DISCOVERY = 2
local HARDCORE = 3
local FRESH = 11
local FRESH_HARDCORE = 12

local function logsUrl(seasonId)
  local character = { name = "Arthas", realm = "Area52", displayRealm = "Area 52" }
  for _, link in ipairs(ProfileLinks.Build(character, { regionId = US, projectId = CLASSIC_ERA, seasonId = seasonId })) do
    if link.label == "Warcraft Logs" then
      return link.url
    end
  end
  return nil
end

return function()
  -- test_season_of_discovery_uses_sod_warcraftlogs
  do
    local url = logsUrl(SEASON_OF_DISCOVERY)
    assert(url == "https://sod.warcraftlogs.com/character/us/area-52/arthas", "sod url, got " .. tostring(url))
  end

  -- test_fresh_realms_use_fresh_warcraftlogs
  do
    local url = logsUrl(FRESH)
    assert(url == "https://fresh.warcraftlogs.com/character/us/area-52/arthas", "fresh url, got " .. tostring(url))
  end

  -- test_hardcore_uses_vanilla_warcraftlogs
  do
    local url = logsUrl(HARDCORE)
    assert(url == "https://vanilla.warcraftlogs.com/character/us/area-52/arthas", "hardcore url, got " .. tostring(url))
  end

  -- test_fresh_hardcore_uses_vanilla_warcraftlogs
  do
    local url = logsUrl(FRESH_HARDCORE)
    assert(url == "https://vanilla.warcraftlogs.com/character/us/area-52/arthas", "fresh hardcore url, got " .. tostring(url))
  end

  -- test_season_without_known_site_has_no_warcraftlogs
  do
    assert(logsUrl(SEASON_OF_MASTERY) == nil, "no Warcraft Logs site known for Season of Mastery")
    assert(logsUrl(99) == nil, "no Warcraft Logs site for an unknown season")
  end
end
