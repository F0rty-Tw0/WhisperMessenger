local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local Env = require("tests.helpers.who_lookup_env")

-- The /who lookup option, not "Show player levels", decides whether quiet
-- lookups go out.
local KEY = "me::WOW::firstmoon"

local function findHook(env)
  for _, entry in ipairs(env.hooks) do
    if entry.target == env.api and entry.method == "SendWho" then
      return entry.hook
    end
  end
  return nil
end

local function test_lookups_are_on_by_default()
  WhoLookup._reset()
  assert(WhoLookup.IsEnabled() == true, "lookups start on")
end

local function test_chat_lookup_runs_with_levels_off()
  Env.Case("levels off, chat", nil, function(env)
    DisplayName.Configure({ showPlayerLevels = false })
    Env.AddStranger(env, KEY, "Firstmoon")
    assert(WhoLookup.TryFor(env.runtime, KEY) == true, "the lookup goes out without levels")
    assert(#env.sent == 1)
  end)
end

local function test_name_lookup_runs_with_levels_off()
  Env.Case("levels off, name", nil, function(env)
    DisplayName.Configure({ showPlayerLevels = false })
    assert(WhoLookup.TryForName(env.runtime, "Firstmoon", KEY) == true, "the name lookup goes out without levels")
    assert(#env.sent == 1)
  end)
end

local function test_typed_who_opens_window_with_levels_off()
  Env.Case("levels off, typed who", nil, function(env)
    DisplayName.Configure({ showPlayerLevels = false })
    findHook(env)("n-Someone")
    assert(WhoLookup.IsWindowOpen() == true, "a typed /who answer is still read")
  end)
end

local function test_turning_lookups_back_on_asks_again()
  Env.Case("off then on", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    WhoLookup.SetEnabled(false)
    assert(WhoLookup.TryFor(env.runtime, KEY) == false)
    WhoLookup.SetEnabled(true)
    assert(WhoLookup.IsEnabled() == true)
    assert(WhoLookup.TryFor(env.runtime, KEY) == true, "the lookup goes out once the option is back on")
    assert(#env.sent == 1)
  end)
end

local function test_reset_turns_lookups_back_on()
  WhoLookup.SetEnabled(false)
  WhoLookup._reset()
  assert(WhoLookup.IsEnabled() == true, "reset restores the default")
end

return function()
  test_lookups_are_on_by_default()
  test_chat_lookup_runs_with_levels_off()
  test_name_lookup_runs_with_levels_off()
  test_typed_who_opens_window_with_levels_off()
  test_turning_lookups_back_on_asks_again()
  test_reset_turns_lookups_back_on()
end
