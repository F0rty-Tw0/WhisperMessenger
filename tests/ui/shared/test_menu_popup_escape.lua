local FakeUI = require("tests.helpers.fake_ui")
local EscapeOrder = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeOrder")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
local MenuPopup = require("WhisperMessenger.UI.Shared.MenuPopup")

-- MenuPopup takes part in the window's ESC order like the other popups.

local WINDOW_NAME = "WhisperMessengerWindow"
local MENU_NAME = "WhisperMessengerMenuPopup"
local SAVED_NAMES = {
  "UISpecialFrames",
  "GetUIPanel",
  "GetMouseFoci",
  "RegisterGameMenuEscHandler",
  "C_Timer",
  "UIParent",
  "CreateFrame",
}

local function contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

local function oneButton(root)
  root:CreateButton("Go", function() end)
end

-- Runs fn(env) with a shown messenger window and fresh ESC lists.
-- env.pressEscape() runs the game's close-all sweep over UISpecialFrames.
-- env.nextFrame() runs the C_Timer.After(0) callbacks queued so far.
-- env.open(anchor) opens the popup with one row and names its frame.
local function withWorld(fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = rawget(_G, name)
  end
  local factory = FakeUI.NewFactory()
  local env = { factory = factory, timers = {} }
  rawset(_G, "CreateFrame", factory.CreateFrame)
  rawset(_G, "UIParent", factory.CreateFrame("Frame", "UIParent", nil))
  env.window = factory.CreateFrame("Frame", WINDOW_NAME, nil)
  env.window:Show()
  env.named = { [WINDOW_NAME] = env.window }
  _G.UISpecialFrames = { WINDOW_NAME }
  rawset(_G, "GetUIPanel", function()
    return nil
  end)
  rawset(_G, "GetMouseFoci", function()
    return {}
  end)
  rawset(_G, "RegisterGameMenuEscHandler", nil)
  rawset(_G, "C_Timer", {
    After = function(_delay, callback)
      table.insert(env.timers, callback)
    end,
  })
  function env.nextFrame()
    local due = env.timers
    env.timers = {}
    for _, callback in ipairs(due) do
      callback()
    end
  end
  function env.pressEscape()
    for _, name in ipairs(_G.UISpecialFrames) do
      local special = env.named[name]
      if special and special:IsShown() then
        special:Hide()
      end
    end
  end
  function env.open(anchor)
    local opened = MenuPopup.Open(anchor, oneButton)
    env.named[MENU_NAME] = MenuPopup.GetFrame()
    return opened
  end
  local ok, err = pcall(fn, env)
  MenuPopup.Close()
  PickerPopup.SetEscapeFrameShownHandler(nil)
  PickerPopup.SetGamepadPopupHooks(nil, nil)
  for _, name in ipairs(SAVED_NAMES) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

local function childAnchor(env)
  local anchor = env.factory.CreateFrame("Button", nil, env.window)
  anchor:Show()
  return anchor
end

return function()
  -- test_popup_joins_the_escape_sweep
  withWorld(function(env)
    EscapeOrder.New(env.window).claim()
    assert(env.open(childAnchor(env)) == true, "popup opens")
    assert(contains(_G.UISpecialFrames, MENU_NAME), "popup is in UISpecialFrames")
    env.pressEscape()
    assert(not MenuPopup.IsShown(), "ESC closes the popup")
    assert(env.window:IsShown(), "ESC leaves the window open")
  end)

  -- test_gamepad_hooks_see_open_and_close
  withWorld(function(env)
    local shown, hidden = {}, {}
    PickerPopup.SetGamepadPopupHooks(function(popup)
      table.insert(shown, popup)
    end, function(popup)
      table.insert(hidden, popup)
    end)
    env.open(childAnchor(env))
    assert(#shown == 1 and shown[1] == MenuPopup.GetFrame(), "shown fires once with the popup, got " .. #shown)
    MenuPopup.Close()
    assert(#hidden == 1 and hidden[1] == MenuPopup.GetFrame(), "hidden fires once, got " .. #hidden)
  end)

  -- test_popup_hides_with_window_and_next_escape_closes_window
  withWorld(function(env)
    EscapeOrder.New(env.window).claim()
    local anchor = childAnchor(env)
    env.open(anchor)
    anchor:Hide()
    assert(not MenuPopup.IsShown(), "popup hides with its anchor")
    env.nextFrame()
    assert(contains(_G.UISpecialFrames, WINDOW_NAME), "the next ESC closes the window")
  end)
end
