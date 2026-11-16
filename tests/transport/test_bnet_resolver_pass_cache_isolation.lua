local BNetResolver = require("WhisperMessenger.Transport.BNetResolver")

-- Two saved chats can point at the same friend. What the resolver learns
-- for one of them (a character GUID that proves the friend is in WoW) must
-- not show up on the other, whatever order the pass visits them in.

local GUID = "Player-1-X"

-- One friend who is offline in the friend list, with no account lookup by
-- ID. Only the character GUID lookup reports the friend in WoW.
local function newApi()
  return {
    GetNumFriends = function()
      return 1
    end,
    GetFriendAccountInfo = function(_index)
      return { bnetAccountID = 1, battleTag = "Tag#1", gameAccountInfo = { isOnline = false, clientProgram = "App" } }
    end,
    GetFriendNumGameAccounts = function()
      return 0
    end,
    GetFriendGameAccountInfo = function()
      return nil
    end,
    GetAccountInfoByGUID = function(guid)
      if guid ~= GUID then
        return nil
      end
      local game = { isOnline = true, clientProgram = "WoW", characterName = "Char", playerGuid = guid }
      return { bnetAccountID = 1, battleTag = "Tag#1", gameAccountInfo = game }
    end,
  }
end

local function summary(info)
  if info == nil then
    return "nil"
  end
  local game = info.gameAccountInfo or {}
  return tostring(info.isOnline) .. "|" .. tostring(game.isOnline) .. "|" .. tostring(game.characterName)
end

return function()
  -- test_pass_cache_guid_evidence_for_one_contact_does_not_reach_another

  do
    local expected = summary(BNetResolver.ResolveAccountInfo(newApi(), 1, nil, nil))
    local api = newApi()
    local passCache = BNetResolver.NewPassCache()
    BNetResolver.ResolveAccountInfo(api, 1, GUID, nil, passCache)
    local withoutGuid = summary(BNetResolver.ResolveAccountInfo(api, 1, nil, nil, passCache))
    assert(withoutGuid == expected, "expected " .. expected .. ", got " .. withoutGuid)
  end

  -- test_pass_cache_guid_contact_resolves_the_same_after_a_contact_without_guid

  do
    local expected = summary(BNetResolver.ResolveAccountInfo(newApi(), 1, GUID, nil))
    local api = newApi()
    local passCache = BNetResolver.NewPassCache()
    BNetResolver.ResolveAccountInfo(api, 1, nil, nil, passCache)
    local withGuid = summary(BNetResolver.ResolveAccountInfo(api, 1, GUID, nil, passCache))
    assert(withGuid == expected, "expected " .. expected .. ", got " .. withGuid)
  end
end
