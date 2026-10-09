local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local Env = require("tests.helpers.who_lookup_env")

-- A /who that is not ours (the player's typed /who, another addon) reaches
-- WhoLookup only through the SendWho post-hook. env.api.SendWho is the hooked
-- function, so calling it stands in for that foreign /who.

local KEY = "me::WOW::firstmoon"

local function typedWho(env)
  env.api.SendWho("n-Someone")
end

local function test_typed_who_counts_toward_gap()
  Env.Case("typed who gap", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    typedWho(env)
    env.clock = env.clock + 2
    assert(WhoLookup.TryFor(env.runtime, KEY) == false, "inside the gap")
    assert(#env.sent == 1, "only the typed /who went out")
    env.clock = env.clock + 3
    Env.FireDueTimers(env)
    assert(WhoLookup.TryFor(env.runtime, KEY) == true, "name was not marked asked")
  end)
end

local function test_typed_who_while_suspended_counts_toward_gap()
  Env.Case("suspended typed who gap", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    rawset(_G, "_wmSuspended", true)
    typedWho(env)
    rawset(_G, "_wmSuspended", nil)
    env.clock = env.clock + 2
    assert(WhoLookup.TryFor(env.runtime, KEY) == false, "the server throttles it all the same")
  end)
end

local function test_own_send_who_stays_in_flight()
  Env.Case("own hook", { whoToUi = false }, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    assert(WhoLookup.TryFor(env.runtime, KEY) == true)
    assert(#env.hooks == 1 and #env.sent == 1)
    assert(env.friendsRegistered == false, "FriendsFrame stays unregistered")
    assert(env.whoToUi[#env.whoToUi] == true, "SetWhoToUi not restored yet")
    WhoLookup.OnWhoListUpdate()
    assert(#env.afters == 1, "our result still ends our query")
  end)
end

local function test_foreign_who_while_ours_in_flight_cleans_up_at_once()
  Env.Case("foreign hook", { whoToUi = false }, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    WhoLookup.TryFor(env.runtime, KEY)
    typedWho(env)
    assert(env.friendsRegistered == true, "FriendsFrame re-registered at once")
    assert(env.whoToUi[#env.whoToUi] == false, "SetWhoToUi restored")
    assert(WhoLookup.IsWindowOpen() == true, "results are still recorded")
    WhoLookup.OnWhoListUpdate()
    assert(#env.afters == 0, "no longer in flight")
  end)
end

-- The gap is zeroed so only the open window can hold the query back.
local function test_try_for_skips_while_window_open()
  local gap = WhoLookup.MIN_GAP_SECONDS
  WhoLookup.MIN_GAP_SECONDS = 0
  Env.Case("window open", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    typedWho(env)
    env.clock = env.clock + 2
    assert(WhoLookup.TryFor(env.runtime, KEY) == false, "window still open")
    assert(#env.sent == 1, "only the typed /who went out")
    env.clock = env.clock + 3
    Env.FireDueTimers(env)
    assert(WhoLookup.IsWindowOpen() == false)
    assert(WhoLookup.TryFor(env.runtime, KEY) == true, "name was not marked asked")
  end)
  WhoLookup.MIN_GAP_SECONDS = gap
end

return function()
  test_typed_who_counts_toward_gap()
  test_typed_who_while_suspended_counts_toward_gap()
  test_own_send_who_stays_in_flight()
  test_foreign_who_while_ours_in_flight_cleans_up_at_once()
  test_try_for_skips_while_window_open()
end
