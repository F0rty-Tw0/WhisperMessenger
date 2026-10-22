local FakeUI = require("tests.helpers.fake_ui")
local EscapeOrder = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeOrder")

local WINDOW_NAME = "WhisperMessengerWindow"
local POPUP_NAME = "WhisperMessengerTestPopup"
local SAVED_NAMES = {
  "UISpecialFrames",
  "GetUIPanel",
  "GetMouseFoci",
  "RegisterGameMenuEscHandler",
  "GameMenuEscPriority",
}

local function contains(list, value)
  for _, item in ipairs(list or {}) do
    if item == value then
      return true
    end
  end
  return false
end

-- Runs fn(env) with a shown messenger window, fresh ESC lists and, unless
-- `classic`, Retail's ESC handler registry. env.pressEscape() runs the
-- registered handlers in order and returns whether one took the press.
local function withWorld(classic, fn)
  local saved = {}
  for _, name in ipairs(SAVED_NAMES) do
    saved[name] = _G[name]
  end
  local factory = FakeUI.NewFactory()
  local env = { factory = factory, panels = {}, focus = nil, handlers = {} }
  env.window = factory.CreateFrame("Frame", WINDOW_NAME, nil)
  env.window:Show()
  _G.UISpecialFrames = { WINDOW_NAME }
  rawset(_G, "GetUIPanel", function(slot)
    return env.panels[slot]
  end)
  rawset(_G, "GetMouseFoci", function()
    return { env.focus }
  end)
  rawset(_G, "RegisterGameMenuEscHandler", nil)
  rawset(_G, "GameMenuEscPriority", nil)
  if not classic then
    rawset(_G, "GameMenuEscPriority", { AddOn = 8 })
    rawset(_G, "RegisterGameMenuEscHandler", function(priority, handler)
      assert(priority == 8, "addon ESC handlers belong in the AddOn bucket")
      table.insert(env.handlers, handler)
    end)
  end
  function env.pressEscape()
    for _, handler in ipairs(env.handlers) do
      if handler() then
        return true
      end
    end
    return false
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
  env.focus = other
  return other
end

return function()
  -- test_escape_closes_only_the_window_in_front
  withWorld(false, function(env)
    EscapeOrder.New(env.window).claim()
    -- Death, loss of control and opening a center panel still close it.
    assert(contains(_G.UISpecialFrames, WINDOW_NAME), "the front window must stay in the game's close-all sweeps")
    assert(env.pressEscape() == true, "ESC must stop at the window in front")
    assert(not env.window:IsShown(), "ESC must close the window in front")
  end)

  -- test_escape_passes_on_when_window_is_hidden
  withWorld(false, function(env)
    EscapeOrder.New(env.window).claim()
    env.window:Hide()
    assert(env.pressEscape() == false, "a hidden window must not use up the ESC press")
  end)

  -- test_escape_closes_own_popup_before_the_window
  withWorld(false, function(env)
    local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
    local popup = env.factory.CreateFrame("Frame", POPUP_NAME, nil)
    rawset(_G, POPUP_NAME, popup)
    PickerPopup.RegisterEscape(POPUP_NAME)
    popup:Show()
    EscapeOrder.New(env.window).claim()
    local pressed = env.pressEscape()
    rawset(_G, POPUP_NAME, nil)
    assert(pressed and not popup:IsShown(), "ESC must close the open popup")
    assert(env.window:IsShown(), "the same ESC press must leave the window open")
  end)

  -- test_escape_after_clicking_panel_leaves_window_open
  withWorld(false, function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    clickAuctionHouse(env)
    order.yieldToClickedWindow()
    assert(env.pressEscape() == false, "ESC must go on to close the Auction House")
    assert(env.window:IsShown(), "ESC must not close the messenger behind the Auction House")
    assert(not contains(_G.UISpecialFrames, WINDOW_NAME), "the panel sweep must not close the messenger either")
  end)

  -- test_closing_the_clicked_panel_gives_escape_back
  withWorld(false, function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    local auctionHouse = clickAuctionHouse(env)
    order.yieldToClickedWindow()
    auctionHouse:Hide()
    assert(env.pressEscape() == true and not env.window:IsShown(), "after the Auction House closes, the next ESC must close the messenger")
  end)

  -- test_click_on_other_addon_window_leaves_escape_to_it
  withWorld(false, function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    clickOtherAddonWindow(env)
    order.yieldToClickedWindow()
    assert(env.pressEscape() == false, "ESC must close the clicked addon window first")
  end)

  -- test_click_on_non_window_keeps_escape
  -- Action bars and the game world never close on ESC, so clicking them
  -- must not stop ESC from closing the messenger.
  withWorld(false, function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    env.focus = env.factory.CreateFrame("Button", "ActionButton1", nil)
    order.yieldToClickedWindow()
    assert(env.pressEscape() == true, "a click on an action bar must keep ESC on the messenger")
  end)

  -- test_stale_panel_hide_does_not_give_escape_back
  withWorld(false, function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    local auctionHouse = clickAuctionHouse(env)
    order.yieldToClickedWindow()
    order.claim()
    clickOtherAddonWindow(env)
    order.yieldToClickedWindow()
    auctionHouse:Hide()
    assert(env.pressEscape() == false, "the window ESC now belongs to is still open")
  end)

  -- test_classic_front_window_closes_with_the_panel_sweep
  -- Classic has no ESC handler registry: the window stays in the sweep.
  withWorld(true, function(env)
    EscapeOrder.New(env.window).claim()
    assert(contains(_G.UISpecialFrames, WINDOW_NAME), "front window must still close on ESC")
  end)

  -- test_classic_click_on_panel_leaves_the_sweep_until_it_closes
  withWorld(true, function(env)
    local order = EscapeOrder.New(env.window)
    order.claim()
    local auctionHouse = clickAuctionHouse(env)
    order.yieldToClickedWindow()
    assert(not contains(_G.UISpecialFrames, WINDOW_NAME), "ESC must close the Auction House without the messenger")
    auctionHouse:Hide()
    assert(contains(_G.UISpecialFrames, WINDOW_NAME), "after the Auction House closes, ESC must close the messenger again")
  end)
end
