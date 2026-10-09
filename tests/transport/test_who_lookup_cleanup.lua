local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local Env = require("tests.helpers.who_lookup_env")

local KEY = "me::WOW::firstmoon"

local function test_query_hides_friends_frame_until_result()
  Env.Case("result cleanup", { whoToUi = true }, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    WhoLookup.TryFor(env.runtime, KEY)
    assert(env.friendsRegistered == false)
    assert(env.whoToUi[1] == true)
    WhoLookup.OnWhoListUpdate()
    assert(env.friendsRegistered == false, "re-register waits a frame")
    assert(#env.afters == 1 and env.afters[1].seconds == 0)
    Env.RunAfters(env)
    assert(env.friendsRegistered == true)
    assert(env.whoToUi[#env.whoToUi] == true, "restored to previous value")
  end)
end

local function test_cleanup_restores_false_without_get_who_to_ui()
  Env.Case("restore false", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    WhoLookup.TryFor(env.runtime, KEY)
    WhoLookup.OnWhoListUpdate()
    Env.RunAfters(env)
    assert(#env.whoToUi == 2)
    assert(env.whoToUi[2] == false)
  end)
end

local function test_who_list_update_not_ours_does_nothing()
  Env.Case("not ours", nil, function(env)
    WhoLookup.OnWhoListUpdate()
    assert(#env.afters == 0)
    assert(#env.whoToUi == 0)
  end)
end

local function test_no_result_cleans_up_on_window_timeout()
  Env.Case("timeout cleanup", nil, function(env)
    Env.AddStranger(env, KEY, "Firstmoon")
    WhoLookup.TryFor(env.runtime, KEY)
    env.clock = env.clock + WhoLookup.WINDOW_SECONDS
    assert(Env.FireDueTimers(env) >= 1)
    assert(env.friendsRegistered == true)
    assert(env.whoToUi[#env.whoToUi] == false)
    assert(WhoLookup.IsWindowOpen() == false)
  end)
end

local function test_open_window_twice_extends()
  Env.Case("extend", nil, function(env)
    local opened, closed = 0, 0
    env.runtime.seenLevelEvents = {
      OpenWhoWindow = function()
        opened = opened + 1
      end,
      CloseWhoWindow = function()
        closed = closed + 1
      end,
    }
    WhoLookup.OpenWindow()
    env.clock = env.clock + 3
    WhoLookup.OpenWindow()
    assert(opened == 2)
    env.clock = env.clock + 2
    Env.FireDueTimers(env)
    assert(WhoLookup.IsWindowOpen() == true, "still open 5 s after the first")
    assert(closed == 0)
    env.clock = env.clock + 3
    Env.FireDueTimers(env)
    assert(WhoLookup.IsWindowOpen() == false, "closed 5 s after the second")
    assert(closed == 1)
  end)
end

local function test_open_window_tolerates_missing_methods()
  Env.Case("no methods", nil, function(env)
    env.runtime.seenLevelEvents = {}
    WhoLookup.OpenWindow()
    env.clock = env.clock + WhoLookup.WINDOW_SECONDS
    Env.FireDueTimers(env)
    assert(WhoLookup.IsWindowOpen() == false)
  end)
end

local function test_open_window_without_runtime_is_noop()
  Env.Case("no runtime", nil, function(env)
    WhoLookup._reset()
    WhoLookup.OpenWindow()
    assert(WhoLookup.IsWindowOpen() == false)
    assert(#env.timers == 0)
  end)
end

local function findHook(env)
  for _, entry in ipairs(env.hooks) do
    if entry.target == env.api and entry.method == "SendWho" then
      return entry.hook
    end
  end
  return nil
end

local function test_typed_who_opens_window()
  Env.Case("typed /who", nil, function(env)
    local hook = assert(findHook(env), "hook installed on C_FriendList.SendWho")
    hook("n-Someone")
    assert(WhoLookup.IsWindowOpen() == true)
  end)
end

local function test_typed_who_ignored_when_suspended_or_off()
  Env.Case("suspended", nil, function(env)
    rawset(_G, "_wmSuspended", true)
    findHook(env)("n-Someone")
    assert(WhoLookup.IsWindowOpen() == false)
  end)
  Env.Case("option off", nil, function(env)
    DisplayName.Configure({ showPlayerLevels = false })
    findHook(env)("n-Someone")
    assert(WhoLookup.IsWindowOpen() == false)
  end)
end

local function test_hook_installed_once()
  Env.Case("hook once", nil, function(env)
    WhoLookup.Init(env.runtime)
    assert(#env.hooks == 1)
  end)
end

local function test_init_without_hooksecurefunc()
  Env.Case("no hooksecurefunc", nil, function(env)
    WhoLookup._reset()
    env.hooks = {}
    rawset(_G, "hooksecurefunc", nil)
    WhoLookup.Init(env.runtime)
    assert(#env.hooks == 0)
  end)
end

return function()
  test_query_hides_friends_frame_until_result()
  test_cleanup_restores_false_without_get_who_to_ui()
  test_who_list_update_not_ours_does_nothing()
  test_no_result_cleans_up_on_window_timeout()
  test_open_window_twice_extends()
  test_open_window_tolerates_missing_methods()
  test_open_window_without_runtime_is_noop()
  test_typed_who_opens_window()
  test_typed_who_ignored_when_suspended_or_off()
  test_hook_installed_once()
  test_init_without_hooksecurefunc()
end
