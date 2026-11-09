local FakeUI = require("tests.helpers.fake_ui")
local EscapeOrder = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeOrder")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")

local WINDOW_NAME = "WhisperMessengerWindow"
local POPUP_NAME = "WhisperMessengerSettingTestPopup"
local SAVED_NAMES = { "UISpecialFrames", "C_Timer", "GetUIPanel", "GetMouseFoci" }

local function contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

local function listed()
  return contains(_G.UISpecialFrames, WINDOW_NAME)
end

-- Runs fn(env) with a shown window under a shown parent, an ESC key spy and
-- the "Esc closes the window" setting in env.escOn (default on).
-- env.newOrder() builds the order with the setting getter; env.nextFrame()
-- runs the C_Timer.After(0) callbacks queued so far.
local function withWindow(fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = _G[name]
  end
  local factory = FakeUI.NewFactory()
  local env = { factory = factory, escOn = true, focused = nil, timers = {} }
  env.parent = factory.CreateFrame("Frame", "UIParent", nil)
  env.parent:Show()
  env.window = factory.CreateFrame("Frame", WINDOW_NAME, env.parent)
  env.window:Show()
  env.escapeKey = {
    setFocused = function(value)
      env.focused = value
    end,
  }
  _G.UISpecialFrames = {}
  rawset(_G, "GetUIPanel", nil)
  rawset(_G, "GetMouseFoci", nil)
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
  function env.newOrder()
    return EscapeOrder.New(env.window, env.escapeKey, function()
      return env.escOn
    end)
  end
  local ok, err = pcall(fn, env)
  for _, name in ipairs(SAVED_NAMES) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

return function()
  -- test_disabled_claim_leaves_window_unlisted_and_unbound
  withWindow(function(env)
    env.escOn = false
    local order = env.newOrder()
    order.claim()
    assert(not listed(), "with Esc off the window must stay out of UISpecialFrames")
    assert(env.focused == false, "with Esc off the window must not hold the ESC key")
  end)

  -- test_disabled_new_removes_build_time_entry
  withWindow(function(env)
    _G.UISpecialFrames = { WINDOW_NAME }
    env.escOn = false
    env.newOrder()
    assert(not listed(), "the entry the window builder added must go when Esc is off")
  end)

  -- test_refresh_after_turning_off_unlists_open_window
  withWindow(function(env)
    local order = env.newOrder()
    order.claim()
    assert(listed() and env.focused == true, "precondition: the open window holds ESC")
    env.escOn = false
    order.refresh()
    assert(not listed(), "turning Esc off unlists the open window")
    assert(env.focused == false, "turning Esc off releases the ESC key")
  end)

  -- test_refresh_after_turning_off_unlists_hidden_window
  withWindow(function(env)
    local order = env.newOrder()
    order.claim()
    env.window:Hide()
    order.release()
    env.escOn = false
    order.refresh()
    assert(not listed(), "turning Esc off unlists a closed window too")
  end)

  -- test_refresh_after_turning_on_lists_open_window
  withWindow(function(env)
    env.escOn = false
    local order = env.newOrder()
    order.claim()
    env.escOn = true
    order.refresh()
    assert(listed(), "turning Esc on lists the open window")
    assert(env.focused == true, "turning Esc on gives the open window the ESC key")
  end)

  -- test_refresh_on_while_hidden_lists_nothing
  withWindow(function(env)
    env.escOn = false
    local order = env.newOrder()
    env.window:Hide()
    env.escOn = true
    order.refresh()
    assert(not listed(), "a hidden window waits for its next show before it is listed")
    assert(env.focused ~= true, "a hidden window must not take the ESC key")
  end)

  -- test_disabled_blocker_hidden_does_not_relist
  withWindow(function(env)
    env.escOn = false
    local order = env.newOrder()
    order.claim()
    local popup = env.factory.CreateFrame("Frame", POPUP_NAME, nil)
    popup:Hide()
    PickerPopup.RegisterEscape(POPUP_NAME, popup)
    popup:Show()
    popup:Hide()
    env.nextFrame()
    assert(not listed(), "a closed blocker must not put the window back while Esc is off")
    assert(env.focused == false, "a closed blocker must not hand ESC back while Esc is off")
  end)

  -- test_disabled_alt_z_round_trip_stays_unlisted
  withWindow(function(env)
    env.escOn = false
    local order = env.newOrder()
    order.claim()
    env.parent:Hide()
    env.parent:Show()
    assert(not listed(), "Alt+Z must not list a window with Esc off")
  end)

  -- test_no_getter_behaves_as_enabled
  withWindow(function(env)
    local order = EscapeOrder.New(env.window, env.escapeKey)
    order.claim()
    assert(listed(), "without a setting getter ESC closes the window as before")
    assert(env.focused == true, "without a setting getter the window takes the ESC key")
  end)
end
