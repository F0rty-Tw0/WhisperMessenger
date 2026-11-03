-- The require shim strips the "WhisperMessenger." prefix, so the module is
-- cached under "Core.FlavorCompat". Clear both keys to be safe.
local function loadFlavorCompat(projectId, tocVersion)
  local savedProjectId = _G.WOW_PROJECT_ID
  local savedGetBuildInfo = _G.GetBuildInfo

  _G.WOW_PROJECT_ID = projectId
  if tocVersion then
    _G.GetBuildInfo = function()
      return "1.60.1", "69913", "Sep 17 2026", tocVersion
    end
  else
    _G.GetBuildInfo = nil
  end

  package.loaded["Core.FlavorCompat"] = nil
  package.loaded["WhisperMessenger.Core.FlavorCompat"] = nil
  local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")

  _G.WOW_PROJECT_ID = savedProjectId
  _G.GetBuildInfo = savedGetBuildInfo
  package.loaded["Core.FlavorCompat"] = nil
  package.loaded["WhisperMessenger.Core.FlavorCompat"] = nil

  return FlavorCompat
end

-- The lookups read the globals live on every call, so the loaded module works.
local function testRegionAndSeasonLookups()
  local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
  local savedGetCurrentRegion = rawget(_G, "GetCurrentRegion")
  local savedSeasons = rawget(_G, "C_Seasons")

  -- Restore the stubs even when an assert fails, so later tests see the real globals.
  local ok, err = pcall(function()
    rawset(_G, "GetCurrentRegion", function()
      return 3
    end)
    assert(FlavorCompat.CurrentRegion() == 3, "CurrentRegion returns the region id")
    rawset(_G, "GetCurrentRegion", nil)
    assert(FlavorCompat.CurrentRegion() == nil, "CurrentRegion is nil without the API")
    rawset(_G, "GetCurrentRegion", function()
      error("region unavailable")
    end)
    assert(FlavorCompat.CurrentRegion() == nil, "CurrentRegion swallows an API error")

    rawset(_G, "C_Seasons", {
      GetActiveSeason = function()
        return 2
      end,
    })
    assert(FlavorCompat.ActiveSeason() == 2, "ActiveSeason returns the season id")
    rawset(_G, "C_Seasons", nil)
    assert(FlavorCompat.ActiveSeason() == nil, "ActiveSeason is nil without C_Seasons")
    rawset(_G, "C_Seasons", {})
    assert(FlavorCompat.ActiveSeason() == nil, "ActiveSeason is nil without GetActiveSeason")
    rawset(_G, "C_Seasons", {
      GetActiveSeason = function()
        error("season unavailable")
      end,
    })
    assert(FlavorCompat.ActiveSeason() == nil, "ActiveSeason swallows an API error")
  end)

  rawset(_G, "GetCurrentRegion", savedGetCurrentRegion)
  rawset(_G, "C_Seasons", savedSeasons)
  assert(ok, err)
end

return function()
  testRegionAndSeasonLookups()

  -- Forever: retail engine (project 1) + toc 16001
  local forever = loadFlavorCompat(1, 16001)
  assert(forever.isForever == true, "toc 16001 should be Forever")
  assert(forever.isRetail == true, "Forever runs the retail engine, isRetail stays true")
  assert(forever.hasMythicPlus == false, "Forever has no Mythic+")

  -- Retail: project 1 + toc 120100
  local retail = loadFlavorCompat(1, 120100)
  assert(retail.isForever == false, "toc 120100 should not be Forever")
  assert(retail.isRetail == true, "toc 120100 should be Retail")
  assert(retail.hasMythicPlus == true, "Retail has Mythic+")

  -- GetBuildInfo nil (test harness default): never Forever
  local noBuild = loadFlavorCompat(1, nil)
  assert(noBuild.isForever == false, "missing GetBuildInfo should not be Forever")
  assert(noBuild.hasMythicPlus == true, "missing GetBuildInfo keeps Retail Mythic+")

  -- Restore the module for any later test that requires it
  require("WhisperMessenger.Core.FlavorCompat")
end
