local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

-- RefreshPresence falls back to a full rescan for a GUID missing from the
-- index. A GUID the rescan still misses stops paying for one, until a later
-- rescan indexes it again.

local function makeGuild(members)
  local counts = { rescans = 0 }
  local api = {
    GetGuildClubId = function()
      return 1
    end,
    GetSubscribedClubs = function()
      return {}
    end,
    GetClubMembers = function()
      counts.rescans = counts.rescans + 1
      local ids = {}
      for i = 1, #members do
        ids[i] = i
      end
      return ids
    end,
    GetMemberInfo = function(_clubId, memberId)
      return members[memberId]
    end,
  }
  return api, counts
end

local function staleRefresh(clock, guid)
  clock.now = clock.now + 300
  PresenceCache.Invalidate()
  return PresenceCache.RefreshPresence(guid)
end

return function()
  -- test_guid_found_again_gets_rescans_back
  do
    local clock = { now = 0 }
    local members = { { guid = "Player-OTHER", presence = 1 } }
    local api, counts = makeGuild(members)
    PresenceCache._initForTest(api, {
      now = function()
        return clock.now
      end,
    })
    staleRefresh(clock, "Player-BACK")
    assert(counts.rescans == 2, "first miss rescans, got " .. counts.rescans)

    -- Rejoins; the next login rebuild indexes them as member 2.
    members[2] = { guid = "Player-BACK", presence = 1 }
    PresenceCache.Rebuild()
    assert(PresenceCache.RefreshPresence("Player-BACK") == "online", "indexed again after a rebuild")

    -- Member IDs shift: slot 2 is somebody else now.
    members[1], members[2] = members[2], members[1]
    local before = counts.rescans
    assert(staleRefresh(clock, "Player-BACK") == "online", "a shifted member is found by a rescan")
    assert(counts.rescans == before + 1, "found again: misses rescan again")
  end

  -- test_empty_rescan_does_not_stop_rescans
  -- Roster not loaded yet: a rescan that sees nobody proves nothing.
  do
    local clock = { now = 0 }
    local members = {}
    local api, counts = makeGuild(members)
    PresenceCache._initForTest(api, {
      now = function()
        return clock.now
      end,
    })
    staleRefresh(clock, "Player-SOON")
    staleRefresh(clock, "Player-SOON")
    assert(counts.rescans == 3, "an empty roster keeps the rescan fallback, got " .. counts.rescans)
    members[1] = { guid = "Player-SOON", presence = 1 }
    assert(staleRefresh(clock, "Player-SOON") == "online", "found once the roster loads")
  end

  PresenceCache._reset()
end
