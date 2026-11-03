local GameAccountProbe = require("WhisperMessenger.Transport.BNetResolver.GameAccountProbe")

local APP_ACCOUNT = { isOnline = true }
local WOW_ACCOUNT = { isOnline = true, characterName = "Redfer" }

local function buildApi(accounts)
  return {
    GetFriendNumGameAccounts = function(_index)
      return #accounts
    end,
    GetFriendGameAccountInfo = function(_index, j)
      return accounts[j]
    end,
  }
end

return function()
  -- test_prefers_account_with_character_over_earlier_app_account

  do
    local info = { isOnline = nil }
    local result = GameAccountProbe.Probe(buildApi({ APP_ACCOUNT, WOW_ACCOUNT }), 1, info)
    assert(result == info, "probe must return the enriched accountInfo")
    assert(info.isOnline == true, "probe must mark the account online")
    assert(info.gameAccountInfo == WOW_ACCOUNT, "the WoW account with a character must win")
  end

  -- test_app_only_fallback_keeps_existing_character

  do
    local existing = { characterName = "Redfer" }
    local info = { isOnline = nil, gameAccountInfo = existing }
    GameAccountProbe.Probe(buildApi({ APP_ACCOUNT }), 1, info)
    assert(info.isOnline == true, "an online app account proves presence")
    assert(info.gameAccountInfo == existing, "an app-only pick must not replace a known character")
  end

  -- test_skips_when_presence_already_known

  do
    local info = { isOnline = false }
    assert(GameAccountProbe.Probe(buildApi({ WOW_ACCOUNT }), 1, info) == nil, "known presence must not be probed")
    assert(info.gameAccountInfo == nil, "skipped probe must not mutate accountInfo")
  end

  -- test_no_online_account_returns_nil

  do
    local info = { isOnline = nil }
    assert(GameAccountProbe.Probe(buildApi({ { isOnline = false } }), 1, info) == nil, "offline accounts prove nothing")
    assert(info.isOnline == nil, "failed probe must leave isOnline nil")
  end
end
