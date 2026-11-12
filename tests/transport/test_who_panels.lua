local WhoPanels = require("WhisperMessenger.Transport.WhoPanels")

local function withGlobals(globals, fn)
  local saved = {}
  for name, value in pairs(globals) do
    saved[name] = rawget(_G, name)
    rawset(_G, name, value)
  end
  local ok, err = pcall(fn)
  for name in pairs(globals) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

local function fakeEnv(whoToUi, whoFrameVisible)
  local env = { whoToUi = whoToUi, calls = {} }
  env.globals = {
    C_FriendList = {
      GetWhoToUi = function()
        return env.whoToUi
      end,
      SetWhoToUi = function(on)
        env.whoToUi = on
      end,
    },
    FriendsFrame = {
      RegisterEvent = function(_self, event)
        env.calls[#env.calls + 1] = "register:" .. event
      end,
      UnregisterEvent = function(_self, event)
        env.calls[#env.calls + 1] = "unregister:" .. event
      end,
    },
    WhoFrame = {
      IsVisible = function()
        return whoFrameVisible
      end,
    },
  }
  return env
end

local function test_claim_mutes_the_panels_and_returns_the_old_flag()
  local env = fakeEnv(false, false)
  withGlobals(env.globals, function()
    assert(WhoPanels.Claim() == false, "returns the flag from before")
  end)
  assert(env.whoToUi == true, "the answer goes to the UI while in flight")
  assert(env.calls[1] == "unregister:WHO_LIST_UPDATE", table.concat(env.calls, ","))
end

local function test_release_restores_the_old_flag()
  local env = fakeEnv(true, false)
  withGlobals(env.globals, function()
    WhoPanels.Release(false)
  end)
  assert(env.whoToUi == false, "flag back to what it was")
  assert(env.calls[1] == "register:WHO_LIST_UPDATE", table.concat(env.calls, ","))
end

local function test_release_keeps_the_flag_while_a_who_panel_shows()
  local env = fakeEnv(true, true)
  withGlobals(env.globals, function()
    WhoPanels.Release(false)
  end)
  assert(env.whoToUi == true, "a Who panel on screen keeps the flag on")
end

return function()
  test_claim_mutes_the_panels_and_returns_the_old_flag()
  test_release_restores_the_old_flag()
  test_release_keeps_the_flag_while_a_who_panel_shows()
end
