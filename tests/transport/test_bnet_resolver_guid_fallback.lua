local GuidFallback = require("WhisperMessenger.Transport.BNetResolver.GuidFallback")

local GUID = "Player-1084-00000001"

local function buildApi(byGuidInfo)
  return {
    GetAccountInfoByGUID = function(guid)
      assert(guid == GUID, "unexpected guid " .. tostring(guid))
      return byGuidInfo
    end,
  }
end

return function()
  -- test_same_person_merges_presence_and_flags

  do
    local gameInfo = { characterName = "Redfer" }
    local api = buildApi({ battleTag = "Nergrom#2503", isOnline = nil, isDND = true, gameAccountInfo = gameInfo })
    local accountInfo = { battleTag = "Nergrom#2503", isOnline = nil }
    local result = GuidFallback.Resolve(api, GUID, accountInfo, false)
    assert(result == accountInfo, "same person must merge into accountInfo")
    assert(accountInfo.isOnline == true, "a character proves presence")
    assert(accountInfo.gameAccountInfo == gameInfo, "game info must merge")
    assert(accountInfo.isDND == true, "DND flag must carry over")
  end

  -- test_different_person_online_returns_guid_result

  do
    local byGuid = { battleTag = "Other#1", isOnline = true }
    local accountInfo = { battleTag = "Nergrom#2503", isOnline = nil }
    assert(GuidFallback.Resolve(buildApi(byGuid), GUID, accountInfo, false) == byGuid, "shifted ID: GUID result wins")
  end

  -- test_different_person_sticky_afk_is_not_presence

  do
    local byGuid = { battleTag = "Other#1", isOnline = false, isAFK = true }
    local accountInfo = { battleTag = "Nergrom#2503", isOnline = nil }
    assert(GuidFallback.Resolve(buildApi(byGuid), GUID, accountInfo, false) == nil, "sticky AFK must not prove presence")
  end

  -- test_stale_id_without_account_returns_guid_result_unconditionally

  do
    local byGuid = { battleTag = "Nergrom#2503", isOnline = false }
    assert(GuidFallback.Resolve(buildApi(byGuid), GUID, nil, true) == byGuid, "stale ID must take the GUID result as is")
  end

  -- test_known_presence_skips_lookup

  do
    local api = {
      GetAccountInfoByGUID = function()
        error("must not be called")
      end,
    }
    assert(GuidFallback.Resolve(api, GUID, { isOnline = true }, false) == nil, "known presence needs no fallback")
  end
end
