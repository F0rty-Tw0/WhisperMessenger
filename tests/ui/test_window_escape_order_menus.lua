local FakeUI = require("tests.helpers.fake_ui")
local EscapeOrder = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeOrder")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")

-- A game menu the window opens (contact or bubble right-click menu, a
-- settings dropdown) closes on ESC before the window, like its own popups.

local WINDOW_NAME = "WhisperMessengerWindow"
local SAVED_NAMES = { "UISpecialFrames", "C_Timer" }

local function contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

-- Runs fn(env) with a shown window in front. env.key.focused tracks the ESC
-- key; env.openMenu() reports a shown menu frame whose hooks are dropped,
-- like pooled game menus that reset their scripts on reuse; env.runTimers()
-- runs the C_Timer callbacks queued so far.
local function withWindow(fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = rawget(_G, name)
  end
  local factory = FakeUI.NewFactory()
  local env = { timers = {}, key = {} }
  function env.key.setFocused(focused)
    env.key.focused = focused
  end
  rawset(_G, "UISpecialFrames", {})
  rawset(_G, "C_Timer", {
    After = function(_delay, callback)
      table.insert(env.timers, callback)
    end,
  })
  function env.runTimers()
    local due = env.timers
    env.timers = {}
    for _, callback in ipairs(due) do
      callback()
    end
  end
  function env.openMenu()
    local menu = factory.CreateFrame("Frame", nil, nil)
    rawset(menu, "HookScript", function() end)
    menu:Show()
    PickerPopup.ReportMenuShown(menu)
    return menu
  end

  local ok, err = pcall(function()
    env.window = factory.CreateFrame("Frame", WINDOW_NAME, nil)
    env.window:Show()
    env.order = EscapeOrder.New(env.window, env.key)
    env.order.claim()
    fn(env)
  end)
  PickerPopup.SetEscapeFrameShownHandler(nil)
  for _, name in ipairs(SAVED_NAMES) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

return function()
  -- test_open_menu_gets_escape_first
  withWindow(function(env)
    env.openMenu()
    assert(env.key.focused == false, "ESC must close the open menu, not the window")
    assert(not contains(_G.UISpecialFrames, WINDOW_NAME), "the close-all sweep must leave the window open")
  end)

  -- test_click_inside_menu_keeps_escape_on_it
  -- A dropdown opens on mouse down, before the window hears that click.
  withWindow(function(env)
    env.openMenu()
    env.order.claim()
    assert(env.key.focused == false, "a click on the window must not take ESC from its open menu")
  end)

  -- test_open_menu_keeps_escape_until_it_closes
  withWindow(function(env)
    env.openMenu()
    env.runTimers()
    env.runTimers()
    assert(env.key.focused == false, "ESC must stay with the menu while it is open")
  end)

  -- test_window_takes_escape_back_after_menu_closes
  withWindow(function(env)
    local menu = env.openMenu()
    menu:Hide()
    env.runTimers()
    env.runTimers()
    assert(env.key.focused == true, "after the menu closes, ESC must close the window again")
    assert(contains(_G.UISpecialFrames, WINDOW_NAME), "the window must rejoin the close-all sweep")
  end)
end
