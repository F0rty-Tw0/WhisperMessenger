local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local SeenZone = require("WhisperMessenger.Model.SeenZone")
local Env = require("tests.helpers.who_lookup_env")

-- TryForName: the game opens the chat a frame after the click, so the /who
-- goes out by name while the conversation may not exist yet.
local KEY = "me::WOW::firstmoon"

local function test_name_without_chat_sends_quiet_who()
  Env.Case("no chat yet", nil, function(env)
    assert(WhoLookup.TryForName(env.runtime, "Firstmoon", KEY) == true)
    assert(#env.sent == 1 and env.sent[1] == 'n-"Firstmoon"', tostring(env.sent[1]))
  end)
end

local function test_name_with_realm_asks_short_name()
  Env.Case("realm name", nil, function(env)
    WhoLookup.TryForName(env.runtime, "Firstmoon-Area52", KEY)
    assert(env.sent[1] == 'n-"Firstmoon"', tostring(env.sent[1]))
  end)
end

local function test_name_with_option_off_sends_nothing()
  Env.Case("option off", nil, function(env)
    WhoLookup.SetEnabled(false)
    assert(WhoLookup.TryForName(env.runtime, "Firstmoon", KEY) == false)
    assert(#env.sent == 0)
  end)
end

local function test_name_in_competitive_content_sends_nothing()
  Env.Case("competitive", nil, function(env)
    env.competitive = true
    assert(WhoLookup.TryForName(env.runtime, "Firstmoon", KEY) == false)
    assert(#env.sent == 0)
  end)
end

local function test_name_asked_recently_sends_nothing()
  Env.Case("asked recently", nil, function(env)
    WhoLookup.TryForName(env.runtime, "Firstmoon", KEY)
    WhoLookup.OnWhoListUpdate()
    Env.RunAfters(env)
    env.clock = env.clock + 60
    Env.FireDueTimers(env)
    assert(WhoLookup.TryForName(env.runtime, "Firstmoon", KEY) == false)
    assert(#env.sent == 1)
  end)
end

local function test_name_with_fresh_zone_sends_nothing()
  Env.Case("fresh zone", nil, function(env)
    SeenZone.Record("Firstmoon", "Dornogal", env.wallClock)
    assert(WhoLookup.TryForName(env.runtime, "Firstmoon", KEY) == false)
    assert(#env.sent == 0)
  end)
end

local function test_existing_chat_uses_its_freshness()
  Env.Case("existing chat", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    WhoLookup.TryFor(env.runtime, KEY)
    WhoLookup.OnWhoListUpdate()
    Env.RunAfters(env)
    env.clock = env.clock + 60
    Env.FireDueTimers(env)
    assert(WhoLookup.TryForName(env.runtime, "Firstmoon", KEY) == false)
    assert(#env.sent == 1)
  end)
end

local function test_existing_battle_net_chat_sends_nothing()
  Env.Case("bnet chat", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon", { channel = "BN" })
    assert(WhoLookup.TryForName(env.runtime, "Firstmoon", KEY) == false)
    assert(#env.sent == 0)
  end)
end

local function test_protected_name_sends_nothing()
  Env.Case("protected name", nil, function(env)
    assert(WhoLookup.TryForName(env.runtime, "|Kq1|k", KEY) == false)
    assert(#env.sent == 0)
  end)
end

return function()
  test_name_without_chat_sends_quiet_who()
  test_name_with_realm_asks_short_name()
  test_name_with_option_off_sends_nothing()
  test_name_in_competitive_content_sends_nothing()
  test_name_asked_recently_sends_nothing()
  test_name_with_fresh_zone_sends_nothing()
  test_existing_chat_uses_its_freshness()
  test_existing_battle_net_chat_sends_nothing()
  test_protected_name_sends_nothing()
end
