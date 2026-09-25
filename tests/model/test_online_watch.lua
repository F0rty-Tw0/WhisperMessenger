local OnlineWatch = require("WhisperMessenger.Model.OnlineWatch")

-- Notify when online: only an observed offline -> online change counts. The
-- first observation of a contact (login / reload burst) just records state.
return function()
  -- test_first_observation_only_records
  do
    local runtime = {}
    assert(OnlineWatch.Observe(runtime, "k", true) == false, "first sight online: no alert")
    assert(OnlineWatch.Observe(runtime, "k", true) == false, "still online: no alert")
  end

  -- test_offline_then_online_is_a_transition
  do
    local runtime = {}
    OnlineWatch.Observe(runtime, "k", false)
    assert(OnlineWatch.Observe(runtime, "k", true) == true, "came online: alert")
    assert(OnlineWatch.Observe(runtime, "k", true) == false, "one alert per login")
    OnlineWatch.Observe(runtime, "k", false)
    assert(OnlineWatch.Observe(runtime, "k", true) == true, "next login alerts again")
  end

  -- test_unknown_state_is_ignored
  do
    local runtime = {}
    OnlineWatch.Observe(runtime, "k", false)
    assert(OnlineWatch.Observe(runtime, "k", nil) == false, "unknown is not a change")
    assert(OnlineWatch.Observe(runtime, "k", true) == true, "unknown keeps the last known state")
  end

  -- test_read_character_friend
  do
    local runtime = {
      friendListApi = {
        GetFriendInfo = function(name)
          if name == "Jaina-Realm" then
            return { connected = false }
          end
          return nil
        end,
      },
    }
    assert(OnlineWatch.ReadOnline(runtime, { channel = "WOW", displayName = "Jaina-Realm" }) == false, "offline friend")
    assert(OnlineWatch.ReadOnline(runtime, { channel = "WOW", displayName = "Nobody-Realm" }) == nil, "not a friend: unknown")
  end

  -- test_read_same_realm_friend_by_short_name
  do
    rawset(_G, "Ambiguate", function(name)
      return (string.gsub(name, "%-.*$", ""))
    end)
    local runtime = {
      friendListApi = {
        GetFriendInfo = function(name)
          return name == "Jaina" and { connected = true } or nil
        end,
      },
    }
    assert(OnlineWatch.ReadOnline(runtime, { channel = "WOW", displayName = "Jaina-Realm" }) == true, "short name lookup")
    rawset(_G, "Ambiguate", nil)
  end

  -- test_read_bnet_friend
  do
    local runtime = {
      bnetApi = {
        GetAccountInfoByID = function()
          return { bnetAccountID = 7, isOnline = false, gameAccountInfo = { isOnline = false } }
        end,
      },
    }
    assert(OnlineWatch.ReadOnline(runtime, { channel = "BN", bnetAccountID = 7 }) == false, "offline Battle.net friend")
  end

  -- test_throwing_api_is_unknown
  do
    local runtime = {
      friendListApi = {
        GetFriendInfo = function()
          error("secret")
        end,
      },
    }
    assert(OnlineWatch.ReadOnline(runtime, { channel = "WOW", displayName = "Jaina-Realm" }) == nil, "error: unknown")
  end

  -- test_can_watch_only_friends
  do
    local api = {
      IsFriend = function(guid)
        return guid == "Player-1"
      end,
    }
    assert(OnlineWatch.CanWatch({ channel = "BN", bnetAccountID = 7 }, api) == true, "Battle.net friend")
    assert(OnlineWatch.CanWatch({ channel = "WOW", guid = "Player-1" }, api) == true, "character friend")
    assert(OnlineWatch.CanWatch({ channel = "WOW", guid = "Player-2" }, api) == false, "stranger")
    assert(OnlineWatch.CanWatch({ channel = "WOW", guid = "Player-2", notifyOnline = true }, api) == true, "already watched: can turn off")
    assert(OnlineWatch.CanWatch({ channel = "WOW", guid = "Player-1" }, {}) == false, "no API: hidden")
  end
end
