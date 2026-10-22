local FakeUI = require("tests.helpers.fake_ui")
local EscapeOrder = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeOrder")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")

local WINDOW_NAME = "WhisperMessengerWindow"
local POPUP_NAME = "WhisperMessengerTestPopup"
local SAVED_NAMES = {
  "UISpecialFrames",
  "GetUIPanel",
  "GetMouseFoci",
  "RegisterGameMenuEscHandler",
  "GameMenuEscPriority",
  "C_Timer",
}

local PANEL_CLOSE_ORDER = { "left", "fullscreen", "doublewide", "center", "right" }

local function contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

-- Runs fn(env) with a shown messenger window and fresh ESC lists.
-- env.pressEscape() runs the game's close-all sweep like CloseWindows: open
-- UI panels hide first, then every shown UISpecialFrames entry.
-- env.nextFrame() runs the C_Timer.After(0) callbacks queued so far.
local function withWorld(fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = _G[name]
  end
  local factory = FakeUI.NewFactory()
  local env = { factory = factory, panels = {}, focus = nil, timers = {} }
  env.window = factory.CreateFrame("Frame", WINDOW_NAME, nil)
  env.window:Show()
  env.named = { [WINDOW_NAME] = env.window }
  _G.UISpecialFrames = { WINDOW_NAME }
  rawset(_G, "GetUIPanel", function(slot)
    return env.panels[slot]
  end)
  rawset(_G, "GetMouseFoci", function()
    return { env.focus }
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
    for _, slot in ipairs(PANEL_CLOSE_ORDER) do
      local panel = env.panels[slot]
      if panel then
        env.panels[slot] = nil
        panel:Hide()
      end
    end
    for _, name in ipairs(_G.UISpecialFrames) do
      local special = env.named[name]
      if special and special:IsShown() then
        special:Hide()
      end
    end
  end
  local ok, err = pcall(fn, env)
  for _, name in ipairs(SAVED_NAMES) do
    rawset(_G, name, saved[name])
  end
  assert(ok, err)
end

-- An open Auction House panel; the click lands on a button inside it.
local function clickAuctionHouse(env)
  local auctionHouse = env.factory.CreateFrame("Frame", "AuctionHouseFrame", nil)
  auctionHouse:Show()
  env.panels.doublewide = auctionHouse
  env.focus = env.factory.CreateFrame("Button", nil, auctionHouse)
  return auctionHouse
end

local function clickOtherAddonWindow(env)
  local other = env.factory.CreateFrame("Frame", "OtherAddonFrame", nil)
  other:Show()
  table.insert(_G.UISpecialFrames, "OtherAddonFrame")
  env.named.OtherAddonFrame = other
  env.focus = other
  return other
end

-- One of the messenger's own popups, hidden until the test shows it.
local function ownPopup(env)
  local popup = env.factory.CreateFrame("Frame", POPUP_NAME, nil)
  popup:Hide()
  env.named[POPUP_NAME] = popup
  PickerPopup.RegisterEscape(POPUP_NAME, popup)
  return popup
end

return function()
  -- test_does_not_use_the_game_esc_handler_registry
  -- Registering there re-sorts Blizzard's handler list from addon code, which
  -- taints ESC: SpellStopCasting is then blocked as an addon action.
  withWorld(function(env)
    local registered = false
    rawset(_G, "GameMenuEscPriority", { AddOn = 8 })
    rawset(_G, "RegisterGameMenuEscHandler", function()
      registered = true
    end)
    EscapeOrder.New(env.window).claim()
    assert(not registered, "ESC handler registry taints ESC for the whole UI")
  end)

  -- test_window_in_front_takes_the_escape_key
  -- Other windows' own ESC handlers (Professions) run before the close-all
  -- sweep, so the window in front needs the key itself.
  withWorld(function(env)
    local key = { focused = nil }
    function key.setFocused(focused)
      key.focused = focused
    end
    local order = EscapeOrder.New(env.window, key)
    order.claim()
    assert(key.focused == true, "the window in front must take ESC")
    ownPopup(env):Show()
    assert(key.focused == false, "an open popup must get ESC first")
    order.claim()
    assert(key.focused == false, "a click inside the popup must leave ESC with it")
  end)

  -- test_clicked_window_and_hidden_window_give_the_escape_key_back
  withWorld(function(env)
    local key = { focused = nil }
    function key.setFocused(focused)
      key.focused = focused
    end
    local order = EscapeOrder.New(env.window, key)
    order.claim()
    clickAuctionHouse(env)
    order.yieldToClickedWindow()
    assert(key.focused == false, "ESC must go to the clicked window")
    order.claim()
    order.release()
    assert(key.focused == false, "a closed messenger must not hold ESC")
  end)

  -- test_escape_closes_the_window_in_front
  withWorld(function(env)
    EscapeOrder.New(env.window).claim()
    env.pressEscape()
    assert(not env.window:IsShown(), "ESC must close the window in front")
  end)

  -- test_escape_closes_own_popup_before_the_window
  withWorld(function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    local popup = ownPopup(env)
    popup:Show()
    env.pressEscape()
    assert(not popup:IsShown(), "ESC must close the open popup")
    assert(env.window:IsShown(), "the same ESC press must leave the window open")
  end)

  -- test_click_inside_own_popup_keeps_escape_on_the_popup
  -- A click on the popup counts as a click on the window, which claims ESC.
  withWorld(function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    ownPopup(env):Show()
    order.claim()
    assert(not contains(_G.UISpecialFrames, WINDOW_NAME), "ESC must still close the popup first")
  end)

  -- test_window_rejoins_escape_the_frame_after_own_popup_closes
  withWorld(function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    local popup = ownPopup(env)
    popup:Show()
    env.pressEscape()
    env.nextFrame()
    assert(contains(_G.UISpecialFrames, WINDOW_NAME), "the next ESC must close the messenger")
  end)

  -- test_click_on_panel_right_after_popup_closes_keeps_escape_on_the_panel
  -- An outside click hides the popup before the window hears the click.
  withWorld(function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    local popup = ownPopup(env)
    popup:Show()
    popup:Hide()
    clickAuctionHouse(env)
    order.yieldToClickedWindow()
    env.nextFrame()
    assert(not contains(_G.UISpecialFrames, WINDOW_NAME), "ESC must close the Auction House without the messenger")
  end)

  -- test_escape_after_clicking_panel_closes_only_the_panel
  -- The sweep hides the panel before it reads UISpecialFrames, so the
  -- panel's OnHide must not put the messenger back into that same sweep.
  withWorld(function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    local auctionHouse = clickAuctionHouse(env)
    order.yieldToClickedWindow()
    env.pressEscape()
    assert(not auctionHouse:IsShown(), "ESC must close the Auction House")
    assert(env.window:IsShown(), "the same ESC press must not close the messenger behind it")
  end)

  -- test_window_rejoins_escape_the_frame_after_the_panel_closes
  withWorld(function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    clickAuctionHouse(env)
    order.yieldToClickedWindow()
    env.pressEscape()
    env.nextFrame()
    env.pressEscape()
    assert(not env.window:IsShown(), "after the Auction House closes, the next ESC must close the messenger")
  end)

  -- test_click_on_other_addon_window_leaves_escape_to_it
  withWorld(function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    local other = clickOtherAddonWindow(env)
    order.yieldToClickedWindow()
    env.pressEscape()
    assert(not other:IsShown() and env.window:IsShown(), "ESC must close the clicked addon window first")
  end)

  -- test_click_on_non_window_keeps_escape
  -- Action bars and the game world never close on ESC, so clicking them
  -- must not stop ESC from closing the messenger.
  withWorld(function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    env.focus = env.factory.CreateFrame("Button", "ActionButton1", nil)
    order.yieldToClickedWindow()
    env.pressEscape()
    assert(not env.window:IsShown(), "a click on an action bar must keep ESC on the messenger")
  end)

  -- test_stale_panel_hide_does_not_give_escape_back
  withWorld(function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    local auctionHouse = clickAuctionHouse(env)
    order.yieldToClickedWindow()
    order.claim()
    clickOtherAddonWindow(env)
    order.yieldToClickedWindow()
    auctionHouse:Hide()
    env.nextFrame()
    assert(not contains(_G.UISpecialFrames, WINDOW_NAME), "the window ESC now belongs to is still open")
  end)
end
