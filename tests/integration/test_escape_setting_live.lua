local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local FakeUI = require("tests.helpers.fake_ui")

-- Flipping "Esc closes the window" with the real window open: it leaves
-- UISpecialFrames and gives the Esc key back at once (after combat if needed).

local WINDOW_NAME = "WhisperMessengerWindow"
local ESCAPE_BUTTON_NAME = "WhisperMessengerEscapeButton"

local SAVED_NAMES = {
  "CreateFrame",
  "GetBindingKey",
  "SetOverrideBindingClick",
  "ClearOverrideBindings",
  "InCombatLockdown",
  "UISpecialFrames",
  "UIParent",
}

local function isListed(name)
  for _, listed in ipairs(_G.UISpecialFrames) do
    if listed == name then
      return true
    end
  end
  return false
end

-- Runs fn(env) with a real window, its settings handler and the game's
-- binding API stubbed; env.bound lists the keys overridden now.
local function withOpenWindow(fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = rawget(_G, name)
  end

  local baseFactory = FakeUI.NewFactory()
  local factory = {}
  local env = { bound = {}, inCombat = false }
  factory.CreateFrame = function(frameType, name, parent, template)
    local frame = baseFactory.CreateFrame(frameType, name, parent, template)
    local publicName = frame.name
    frame.name = nil
    rawset(frame, "GetName", function(_self)
      return publicName
    end)
    if publicName == ESCAPE_BUTTON_NAME then
      env.button = frame
    end
    return frame
  end

  rawset(_G, "CreateFrame", factory.CreateFrame)
  rawset(_G, "GetBindingKey", function()
    return "ESCAPE"
  end)
  rawset(_G, "SetOverrideBindingClick", function(_owner, _priority, key)
    table.insert(env.bound, key)
  end)
  rawset(_G, "ClearOverrideBindings", function(_owner)
    for index = #env.bound, 1, -1 do
      env.bound[index] = nil
    end
  end)
  rawset(_G, "InCombatLockdown", function()
    return env.inCombat
  end)
  rawset(_G, "UISpecialFrames", {})
  rawset(_G, "UIParent", factory.CreateFrame("Frame", "UIParent", nil))
  _G.UIParent:Show()

  local ok, err = pcall(function()
    local settings = {}
    env.window = MessengerWindow.Create(factory, {
      title = "WhisperMessenger",
      contacts = {},
      settingsConfig = settings,
    })
    env.onChange = SettingsHandler.Create({
      runtime = { store = { config = {} }, window = env.window },
      accountSettings = settings,
    })
    env.window.frame:Show()
    assert(isListed(WINDOW_NAME), "pre: the open window is listed")
    assert(#env.bound == 1, "pre: the open window holds ESC")
    fn(env)
  end)

  for _, name in ipairs(SAVED_NAMES) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

return function()
  -- test_turning_off_while_open_unlists_window
  withOpenWindow(function(env)
    env.onChange("escapeClosesWindow", false)

    assert(not isListed(WINDOW_NAME), "with Esc off the open window leaves UISpecialFrames")
    assert(#env.bound == 0, "with Esc off the open window gives the ESC key back")
  end)

  -- test_flip_in_combat_rebinds_after_regen
  withOpenWindow(function(env)
    env.inCombat = true
    env.onChange("escapeClosesWindow", false)

    assert(not isListed(WINDOW_NAME), "the window leaves UISpecialFrames at once, even in combat")
    assert(#env.bound == 1, "the key binding cannot change in combat")

    env.inCombat = false
    env.button.scripts.OnEvent(env.button, "PLAYER_REGEN_ENABLED")

    assert(#env.bound == 0, "the ESC key is given back once combat ends")
  end)
end
