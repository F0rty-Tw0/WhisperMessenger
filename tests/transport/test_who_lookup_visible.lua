local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local Env = require("tests.helpers.who_lookup_env")

local function test_visible_who_sends_plain_short_name_query()
  Env.Case("visible send", nil, function(env)
    assert(WhoLookup.SendVisible("Bob-Realm") == true)
    assert(#env.sent == 1, "one /who expected")
    assert(env.sent[1] == 'n-"Bob"', tostring(env.sent[1]))
  end)
end

local function test_visible_who_leaves_who_ui_alone()
  Env.Case("no who ui", nil, function(env)
    WhoLookup.SendVisible("Bob")
    assert(#env.whoToUi == 0, "SetWhoToUi must not be called")
    assert(env.friendsRegistered == true, "FriendsFrame must stay registered")
  end)
end

local function test_visible_who_works_with_levels_off()
  Env.Case("levels off", nil, function(env)
    DisplayName.Configure({ showPlayerLevels = false })
    assert(WhoLookup.SendVisible("Bob") == true)
    assert(#env.sent == 1)
  end)
end

local function test_visible_who_blocked_in_combat_sends_nothing()
  Env.Case("combat", nil, function(env)
    env.inCombat = true
    assert(WhoLookup.SendVisible("Bob") == false)
    assert(#env.sent == 0, "no /who expected")
  end)
end

local function test_second_visible_who_inside_gap_is_throttled()
  Env.Case("throttled", nil, function(env)
    assert(WhoLookup.SendVisible("Bob") == true)
    env.clock = env.clock + 1
    assert(WhoLookup.SendVisible("Carl") == false)
    assert(#env.sent == 1, "second /who expected to be dropped")
  end)
end

local function test_visible_who_after_gap_sends_again()
  Env.Case("after gap", nil, function(env)
    WhoLookup.SendVisible("Bob")
    env.clock = env.clock + WhoLookup.MIN_GAP_SECONDS + WhoLookup.WINDOW_SECONDS
    Env.FireDueTimers(env)
    assert(WhoLookup.SendVisible("Carl") == true)
    assert(env.sent[2] == 'n-"Carl"', tostring(env.sent[2]))
  end)
end

local function test_secret_or_empty_name_sends_nothing()
  Env.Case("bad names", nil, function(env)
    assert(WhoLookup.SendVisible("|Kq1|k") == false)
    assert(WhoLookup.SendVisible(nil) == false)
    assert(WhoLookup.SendVisible("") == false)
    assert(WhoLookup.SendVisible(42) == false)
    assert(#env.sent == 0, "no /who expected")
  end)
end

local function test_visible_who_before_init_sends_nothing()
  Env.Case("before Init", nil, function(env)
    WhoLookup._reset()
    assert(WhoLookup.SendVisible("Bob") == false)
    assert(#env.sent == 0, "no /who expected")
  end)
end

local function test_visible_who_send_error_returns_false()
  Env.Case("send throws", nil, function(env)
    Env.ReplaceSendWho(env, function()
      error("ADDON_ACTION_BLOCKED")
    end)
    assert(WhoLookup.SendVisible("Bob") == false)
  end)
end

return function()
  test_visible_who_sends_plain_short_name_query()
  test_visible_who_leaves_who_ui_alone()
  test_visible_who_works_with_levels_off()
  test_visible_who_blocked_in_combat_sends_nothing()
  test_second_visible_who_inside_gap_is_throttled()
  test_visible_who_after_gap_sends_again()
  test_secret_or_empty_name_sends_nothing()
  test_visible_who_before_init_sends_nothing()
  test_visible_who_send_error_returns_false()
end
