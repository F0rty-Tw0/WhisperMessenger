local RosterLookup = require("WhisperMessenger.Model.RosterLookup")

local function fakeClubApi(membersByClub)
  local clubs = {}
  for clubId in pairs(membersByClub) do
    clubs[#clubs + 1] = { clubId = clubId }
  end
  return {
    GetSubscribedClubs = function()
      return clubs
    end,
    GetClubMembers = function(clubId)
      local ids = {}
      for index in ipairs(membersByClub[clubId]) do
        ids[#ids + 1] = index
      end
      return ids
    end,
    GetMemberInfo = function(clubId, memberId)
      return membersByClub[clubId][memberId]
    end,
  }
end

return function()
  -- test_finds_guid_of_roster_member_by_name_case_insensitive
  do
    local api = fakeClubApi({
      [7] = { { name = "Thrall", guid = "Player-1" }, { name = "Paokremounia", guid = "Player-2" } },
    })
    local guid = RosterLookup.FindGUIDByName(api, "paokremounia")
    assert(guid == "Player-2", "expected roster guid, got " .. tostring(guid))
  end

  -- test_returns_nil_for_unknown_name
  do
    local api = fakeClubApi({ [7] = { { name = "Thrall", guid = "Player-1" } } })
    assert(RosterLookup.FindGUIDByName(api, "Nobody") == nil, "unknown name has no guid")
  end

  -- test_returns_nil_without_club_api
  do
    assert(RosterLookup.FindGUIDByName(nil, "Thrall") == nil, "missing club API is safe")
  end
end
