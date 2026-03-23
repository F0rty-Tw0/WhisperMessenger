local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")

return function()
  -- -----------------------------------------------------------------------
  -- test_get_club_members_returns_non_table_does_not_error
  -- -----------------------------------------------------------------------
  do
    local originalCClub = _G.C_Club
    _G.C_Club = {
      GetGuildClubId = function()
        return 12345
      end,
      GetClubMembers = function(_clubId)
        -- Simulate WoW returning a non-table value (e.g. userdata "secret")
        return nil
      end,
      GetMemberInfo = function(_clubId, _memberId)
        return { guid = "Player-1-001", presence = 1 }
      end,
      GetSubscribedClubs = function()
        return {}
      end,
    }

    local checkFn = RuntimeFactory.BuildGuildOrCommunityPresenceCheck()
    assert(type(checkFn) == "function", "expected presence check function")

    -- Should not error when GetClubMembers returns nil
    local result = checkFn("Player-1-001")
    assert(result == nil, "expected nil when guild members is not a table, got: " .. tostring(result))

    _G.C_Club = originalCClub
  end

  -- -----------------------------------------------------------------------
  -- test_get_club_members_returns_userdata_does_not_error
  -- -----------------------------------------------------------------------
  do
    local originalCClub = _G.C_Club
    local fakeUserdata = setmetatable({}, {
      __type = "secret",
    })

    _G.C_Club = {
      GetGuildClubId = function()
        return 99999
      end,
      GetClubMembers = function(_clubId)
        return fakeUserdata
      end,
      GetMemberInfo = function(_clubId, _memberId)
        return { guid = "Player-1-002", presence = 1 }
      end,
      GetSubscribedClubs = function()
        return {}
      end,
    }

    local checkFn = RuntimeFactory.BuildGuildOrCommunityPresenceCheck()
    assert(type(checkFn) == "function", "expected presence check function")

    -- fakeUserdata is a table due to Lua limitations, but the type guard
    -- should still pass since setmetatable returns a table. Test the nil case
    -- above for the real protection. This test verifies no crash on edge cases.
    local ok, _ = pcall(checkFn, "Player-1-002")
    assert(ok, "expected no error when GetClubMembers returns unusual value")

    _G.C_Club = originalCClub
  end

  -- -----------------------------------------------------------------------
  -- test_normal_members_table_still_works
  -- -----------------------------------------------------------------------
  do
    local originalCClub = _G.C_Club
    _G.C_Club = {
      GetGuildClubId = function()
        return 77777
      end,
      GetClubMembers = function(_clubId)
        return { 1, 2 }
      end,
      GetMemberInfo = function(_clubId, memberId)
        if memberId == 2 then
          return { guid = "Player-1-099", presence = 1 }
        end
        return { guid = "Player-1-000", presence = 3 }
      end,
      GetSubscribedClubs = function()
        return {}
      end,
    }

    local checkFn = RuntimeFactory.BuildGuildOrCommunityPresenceCheck()
    local result = checkFn("Player-1-099")
    assert(result == "online", "expected 'online' for matching guild member, got: " .. tostring(result))

    _G.C_Club = originalCClub
  end
end
