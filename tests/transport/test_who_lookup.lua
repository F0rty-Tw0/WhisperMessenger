local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local SeenLevel = require("WhisperMessenger.Model.SeenLevel")
local Env = require("tests.helpers.who_lookup_env")

local KEY = "me::WOW::firstmoon"
local OTHER_KEY = "me::WOW::secondsun"

local function test_unknown_stranger_sends_quiet_who()
  Env.Case("sends once", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    assert(WhoLookup.TryFor(env.runtime, KEY) == true)
    assert(#env.sent == 1)
    assert(env.sent[1] == 'n-"Firstmoon"', tostring(env.sent[1]))
  end)
end

local function test_same_stranger_twice_sends_one_who()
  Env.Case("same key twice", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    WhoLookup.TryFor(env.runtime, KEY)
    WhoLookup.OnWhoListUpdate()
    Env.RunAfters(env)
    env.clock = env.clock + 60
    Env.FireDueTimers(env)
    assert(WhoLookup.IsWindowOpen() == false, "window should be closed, so only the asked-once memory blocks")
    assert(WhoLookup.TryFor(env.runtime, KEY) == false)
    assert(#env.sent == 1)
  end)
end

local function test_other_stranger_waits_for_min_gap()
  Env.Case("min gap", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    Env.AddStranger(env, OTHER_KEY, "Secondsun")
    WhoLookup.TryFor(env.runtime, KEY)
    WhoLookup.OnWhoListUpdate()
    Env.RunAfters(env)
    env.clock = env.clock + 4
    assert(WhoLookup.TryFor(env.runtime, OTHER_KEY) == false)
    assert(#env.sent == 1)
    env.clock = env.clock + 1
    Env.FireDueTimers(env)
    assert(WhoLookup.TryFor(env.runtime, OTHER_KEY) == true)
    assert(env.sent[2] == 'n-"Secondsun"', tostring(env.sent[2]))
  end)
end

-- runtime.now is whole-second time(): 99 -> 104 reads as a 5 s gap while
-- the client clock moved only 4.5 s.
local function test_min_gap_uses_precise_clock()
  Env.Case("precise gap", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    Env.AddStranger(env, OTHER_KEY, "Secondsun")
    local wall = 99
    env.runtime.now = function()
      return wall
    end
    env.clock = 100.0
    WhoLookup.TryFor(env.runtime, KEY)
    WhoLookup.OnWhoListUpdate()
    Env.RunAfters(env)
    env.clock, wall = 104.5, 104
    Env.FireDueTimers(env)
    assert(WhoLookup.TryFor(env.runtime, OTHER_KEY) == false, "4.5 s is under the gap")
    assert(#env.sent == 1)
    env.clock = 105.0
    Env.FireDueTimers(env)
    assert(WhoLookup.TryFor(env.runtime, OTHER_KEY) == true, "5 s is enough")
  end)
end

local function test_without_new_timer_sends_nothing()
  Env.Case("no NewTimer", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    local timers = _G.C_Timer
    rawset(_G, "C_Timer", { After = timers.After })
    assert(WhoLookup.TryFor(env.runtime, KEY) == false)
    assert(#env.sent == 0, "no /who expected")
    assert(env.friendsRegistered == true and #env.whoToUi == 0, "FriendsFrame untouched")
    rawset(_G, "C_Timer", timers)
    assert(WhoLookup.TryFor(env.runtime, KEY) == true, "name was not marked asked")
  end)
end

local function test_other_stranger_waits_while_ours_in_flight()
  Env.Case("in flight", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    Env.AddStranger(env, OTHER_KEY, "Secondsun")
    WhoLookup.TryFor(env.runtime, KEY)
    env.clock = env.clock + 10
    assert(WhoLookup.TryFor(env.runtime, OTHER_KEY) == false)
    assert(#env.sent == 1)
  end)
end

local function test_realm_suffix_is_dropped_from_query()
  Env.Case("realm dropped", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon-OtherRealm")
    WhoLookup.TryFor(env.runtime, KEY)
    assert(env.sent[1] == 'n-"Firstmoon"', tostring(env.sent[1]))
  end)
end

local function expectSkip(label, setup)
  Env.Case(label, nil, function(env)
    local key = setup(env) or KEY
    assert(WhoLookup.TryFor(env.runtime, key) == false, "TryFor should return false")
    assert(#env.sent == 0, "no /who expected")
    assert(env.friendsRegistered == true)
  end)
end

local function test_skips()
  expectSkip("option off", function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    DisplayName.Configure({ showPlayerLevels = false })
  end)
  expectSkip("level on conversation", function(env)
    Env.AddStranger(env, KEY, "Firstmoon", { characterLevel = 70 })
  end)
  expectSkip("seen level by name", function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    SeenLevel.Record(nil, "Firstmoon", 42)
  end)
  expectSkip("seen level by guid", function(env)
    Env.AddStranger(env, KEY, "Firstmoon", { guid = "Player-1-ABC" })
    SeenLevel.Record("Player-1-ABC", "Someoneelse", 42)
  end)
  expectSkip("battle.net chat", function(env)
    Env.AddStranger(env, KEY, "Firstmoon", { channel = "BN" })
  end)
  expectSkip("combat", function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    env.inCombat = true
  end)
  expectSkip("chat lockdown", function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    env.chatLockdown = true
  end)
  expectSkip("mythic lockdown", function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    env.mythic = true
  end)
  expectSkip("competitive content", function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    env.competitive = true
  end)
  expectSkip("unknown key", function(_env)
    return "me::WOW::nobody"
  end)
end

local function test_send_who_throw_cleans_up_at_once()
  Env.Case("throw", { whoToUi = false }, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    local attempts = 0
    Env.ReplaceSendWho(env, function()
      attempts = attempts + 1
      error("ADDON_ACTION_BLOCKED")
    end)
    assert(WhoLookup.TryFor(env.runtime, KEY) == false)
    assert(env.friendsRegistered == true)
    assert(env.whoToUi[#env.whoToUi] == false)
    env.clock = env.clock + 60
    Env.FireDueTimers(env)
    assert(WhoLookup.IsWindowOpen() == false, "window should be closed, so only the asked-once memory blocks")
    assert(WhoLookup.TryFor(env.runtime, KEY) == false, "name stays asked")
    assert(attempts == 1)
  end)
end

local function test_replaced_send_who_is_called()
  Env.Case("replaced SendWho", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    local wrapped = {}
    Env.ReplaceSendWho(env, function(filter)
      table.insert(wrapped, filter)
    end)
    WhoLookup.TryFor(env.runtime, KEY)
    assert(#wrapped == 1)
    assert(#env.sent == 0)
  end)
end

return function()
  test_unknown_stranger_sends_quiet_who()
  test_same_stranger_twice_sends_one_who()
  test_other_stranger_waits_for_min_gap()
  test_min_gap_uses_precise_clock()
  test_without_new_timer_sends_nothing()
  test_other_stranger_waits_while_ours_in_flight()
  test_realm_suffix_is_dropped_from_query()
  test_skips()
  test_send_who_throw_cleans_up_at_once()
  test_replaced_send_who_is_called()
end
