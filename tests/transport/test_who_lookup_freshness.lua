local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local SeenZone = require("WhisperMessenger.Model.SeenZone")
local Env = require("tests.helpers.who_lookup_env")

local KEY = "me::WOW::firstmoon"
local OTHER_KEY = "me::WOW::secondsun"
local GUID = "Player-1-ABC"

-- Answers the pending /who, lets the window close and moves the clock on.
local function settle(env, seconds)
  WhoLookup.OnWhoListUpdate()
  Env.RunAfters(env)
  env.clock = env.clock + seconds
  Env.FireDueTimers(env)
end

local function withPresence(presence, zone, fn)
  local getPresence, getZone = PresenceCache.GetPresence, PresenceCache.GetZone
  PresenceCache.GetPresence = function()
    return presence
  end
  PresenceCache.GetZone = function()
    return zone
  end
  local ok, err = pcall(fn)
  PresenceCache.GetPresence, PresenceCache.GetZone = getPresence, getZone
  assert(ok, err)
end

local function test_known_level_is_still_asked_when_never_asked()
  Env.Case("known level", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon", { characterLevel = 70 })
    assert(WhoLookup.TryFor(env.runtime, KEY) == true)
    assert(#env.sent == 1, "expected one /who, got " .. #env.sent)
  end)
end

local function test_same_name_not_asked_again_within_ten_minutes()
  Env.Case("under ten minutes", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    WhoLookup.TryFor(env.runtime, KEY)
    settle(env, WhoLookup.STALE_SECONDS - 1)
    assert(WhoLookup.IsWindowOpen() == false)
    assert(WhoLookup.TryFor(env.runtime, KEY) == false)
    assert(#env.sent == 1)
  end)
end

local function test_same_name_asked_again_after_ten_minutes()
  Env.Case("ten minutes", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    WhoLookup.TryFor(env.runtime, KEY)
    settle(env, WhoLookup.STALE_SECONDS)
    assert(WhoLookup.TryFor(env.runtime, KEY) == true)
    assert(#env.sent == 2)
  end)
end

-- The server drops a /who sent too soon after another, without a reply.
local function test_unanswered_who_is_asked_again_on_next_try()
  Env.Case("no answer", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    WhoLookup.TryFor(env.runtime, KEY)
    env.clock = env.clock + WhoLookup.WINDOW_SECONDS
    Env.FireDueTimers(env)
    assert(WhoLookup.TryFor(env.runtime, KEY) == true, "the first /who got no answer")
    assert(#env.sent == 2)
  end)
end

local function test_recent_who_answer_counts_as_fresh()
  Env.Case("recent answer", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    SeenZone.Record("Firstmoon", "Dornogal", env.wallClock - 60)
    assert(WhoLookup.TryFor(env.runtime, KEY) == false)
    assert(#env.sent == 0)
  end)
end

local function test_old_who_answer_is_stale()
  Env.Case("old answer", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    SeenZone.Record("Firstmoon", "Dornogal", env.wallClock - WhoLookup.STALE_SECONDS)
    assert(WhoLookup.TryFor(env.runtime, KEY) == true)
    assert(#env.sent == 1)
  end)
end

local function test_live_presence_zone_is_never_asked()
  Env.Case("live zone", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon", { guid = GUID })
    withPresence("online", "Dornogal", function()
      assert(WhoLookup.TryFor(env.runtime, KEY) == false)
    end)
    assert(#env.sent == 0)
  end)
end

local function test_offline_contact_with_known_guid_is_asked()
  Env.Case("offline contact", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon", { guid = GUID })
    withPresence("offline", "Dornogal", function()
      assert(WhoLookup.TryFor(env.runtime, KEY) == true)
    end)
    assert(#env.sent == 1)
  end)
end

local function test_throttled_attempt_does_not_stamp_ask_time()
  Env.Case("throttled", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    Env.AddStranger(env, OTHER_KEY, "Secondsun")
    WhoLookup.TryFor(env.runtime, OTHER_KEY)
    settle(env, 4)
    assert(WhoLookup.TryFor(env.runtime, KEY) == false, "under 5 s since the other /who")
    assert(#env.sent == 1)
    env.clock = env.clock + 1
    Env.FireDueTimers(env)
    assert(WhoLookup.TryFor(env.runtime, KEY) == true, "throttle cleared")
    assert(#env.sent == 2)
  end)
end

local function test_throwing_send_who_stamps_ask_time()
  Env.Case("throwing send", { whoToUi = false }, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    local attempts = 0
    Env.ReplaceSendWho(env, function()
      attempts = attempts + 1
      error("ADDON_ACTION_BLOCKED")
    end)
    WhoLookup.TryFor(env.runtime, KEY)
    env.clock = env.clock + 60
    Env.FireDueTimers(env)
    assert(WhoLookup.TryFor(env.runtime, KEY) == false, "no retry after a minute")
    env.clock = env.clock + WhoLookup.STALE_SECONDS - 60
    Env.FireDueTimers(env)
    WhoLookup.TryFor(env.runtime, KEY)
    assert(attempts == 2, "expected a retry after ten minutes, attempts: " .. attempts)
  end)
end

return function()
  test_known_level_is_still_asked_when_never_asked()
  test_same_name_not_asked_again_within_ten_minutes()
  test_same_name_asked_again_after_ten_minutes()
  test_unanswered_who_is_asked_again_on_next_try()
  test_recent_who_answer_counts_as_fresh()
  test_old_who_answer_is_stale()
  test_live_presence_zone_is_never_asked()
  test_offline_contact_with_known_guid_is_asked()
  test_throttled_attempt_does_not_stamp_ask_time()
  test_throwing_send_who_stamps_ask_time()
end
