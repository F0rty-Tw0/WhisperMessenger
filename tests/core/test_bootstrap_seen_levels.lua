local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local SeenLevelEvents = require("WhisperMessenger.Core.SeenLevelEvents")
local WhoLookup = require("WhisperMessenger.Transport.WhoLookup")

local function initialize(settings)
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedSuspended = _G._wmSuspended
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G._wmSuspended = nil
  SeenLevelEvents._reset()

  local ok, runtime = pcall(Bootstrap.Initialize, factory, {
    accountState = {
      schemaVersion = 1,
      conversations = {},
      contacts = {},
      pendingHydration = {},
      settings = settings,
    },
    characterState = {
      window = { x = 0, y = 0, width = 900, height = 560 },
      icon = {},
    },
  })

  _G.UIParent = savedUIParent
  _G._wmSuspended = savedSuspended
  assert(ok, runtime)
  return runtime
end

return function()
  -- test_saved_option_on_starts_recording_levels

  do
    local runtime = initialize({ showPlayerLevels = true })
    assert(runtime.seenLevelEvents == SeenLevelEvents, "the runtime exposes the level recorder")
    assert(runtime.seenLevelEvents.IsEnabled() == true, "a saved on choice turns level recording on")
    assert(SeenLevelEvents._frame:IsEventRegistered("PLAYER_TARGET_CHANGED") == true, "target changes are watched")
  end

  -- test_unset_option_leaves_level_recording_off

  do
    local runtime = initialize({})
    assert(runtime.seenLevelEvents.IsEnabled() == false, "an unset choice keeps level recording off")
    assert(SeenLevelEvents._frame:IsEventRegistered("PLAYER_TARGET_CHANGED") == false, "target changes are not watched")
  end

  -- test_initialize_hooks_send_who

  do
    local savedHook = rawget(_G, "hooksecurefunc")
    local savedFriendList = rawget(_G, "C_FriendList")
    local hooks = {}
    local friendList = { SendWho = function() end }
    rawset(_G, "hooksecurefunc", function(target, method, hook)
      hooks[#hooks + 1] = { target = target, method = method, hook = hook }
    end)
    rawset(_G, "C_FriendList", friendList)
    WhoLookup._reset()
    local ok, err = pcall(initialize, { showPlayerLevels = true })
    rawset(_G, "hooksecurefunc", savedHook)
    rawset(_G, "C_FriendList", savedFriendList)
    WhoLookup._reset()
    assert(ok, err)
    local found = false
    for _, entry in ipairs(hooks) do
      if entry.target == friendList and entry.method == "SendWho" and type(entry.hook) == "function" then
        found = true
      end
    end
    assert(found, "Initialize should hook C_FriendList.SendWho")
  end

  SeenLevelEvents._reset()
  DisplayName.Configure({ showPlayerLevels = false })
end
