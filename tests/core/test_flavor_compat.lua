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

return function()
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
