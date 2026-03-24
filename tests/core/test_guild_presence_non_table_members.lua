local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

return function()
  -- -----------------------------------------------------------------------
  -- test_get_club_members_returns_non_table_does_not_error
  -- -----------------------------------------------------------------------
  do
    PresenceCache._reset()
    local api = {
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

    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })

    -- Should not error when GetClubMembers returns nil
    local result = PresenceCache.GetPresence("Player-1-001")
    assert(result == nil, "expected nil when guild members is not a table, got: " .. tostring(result))
  end

  -- -----------------------------------------------------------------------
  -- test_get_club_members_returns_userdata_does_not_error
  -- -----------------------------------------------------------------------
  do
    PresenceCache._reset()
    local fakeUserdata = setmetatable({}, {
      __type = "secret",
    })

    local api = {
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

    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })

    -- fakeUserdata is a table due to Lua limitations, but the type guard
    -- should still pass since setmetatable returns a table. This test verifies
    -- no crash on edge cases.
    local ok, _ = pcall(PresenceCache.GetPresence, "Player-1-002")
    assert(ok, "expected no error when GetClubMembers returns unusual value")
  end

  -- -----------------------------------------------------------------------
  -- test_normal_members_table_still_works
  -- -----------------------------------------------------------------------
  do
    PresenceCache._reset()
    local api = {
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

    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })

    local result = PresenceCache.GetPresence("Player-1-099")
    assert(result == "online", "expected 'online' for matching guild member, got: " .. tostring(result))
  end
end
