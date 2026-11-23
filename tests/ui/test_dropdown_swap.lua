-- On WoW: Forever a settings dropdown pairs WM's own list with the game's
-- dropdown and shows the one that fits the gamepad UI: WM's own while the
-- pad UI is on, the game's while it is off.
local FakeUI = require("tests.helpers.fake_ui")
local Flavor = require("tests.helpers.flavor")
local SwapPair = require("tests.helpers.dropdown_swap_pair")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local NativeDropdown = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.NativeDropdown")
local DropdownSwap = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSwap")

local fakeHandle = SwapPair.FakeHandle
local called = SwapPair.Called
local wrapPair = SwapPair.Wrap
local refresh = SwapPair.Refresh
local last = SwapPair.Last

local LIST = { { key = "a", label = "A" } }
local COLORS = { text = { 1, 1, 1, 1 } }

-- An onChange that puts the pair back on `key`, like a setting that waits
-- for the player to confirm.
local function revertTo(key)
  return function(ctx)
    ctx.wrapped.setSelected(key)
  end
end

local function onForever(fn)
  Flavor.With(true, true, fn)
end

local function withHud(style, fn)
  Hud.Configure(style)
  local ok, err = pcall(fn)
  Hud.Configure("off")
  if not ok then
    error(err, 0)
  end
end

local function wrapTests()
  -- test_pad_on_build_shows_own_and_builds_no_native
  do
    local ctx = wrapPair(true)
    assert(ctx.builds == 0, "pad UI on: no game dropdown built")
    assert(ctx.own.button:IsShown(), "pad UI on: own button shown")
  end

  -- test_pad_off_build_shows_native
  do
    local ctx = wrapPair(false)
    assert(ctx.builds == 1, "pad UI off: game dropdown built once")
    assert(ctx.native.row:IsShown(), "pad UI off: game dropdown shown")
    assert(not ctx.own.button:IsShown(), "pad UI off: own button hidden")
    assert(not ctx.native.label:IsShown(), "game dropdown's own label hidden")
    local point, relativeTo, relativePoint, x, y = ctx.native.button:GetPoint(1)
    assert(point == "TOPLEFT" and relativeTo == ctx.own.button, "game button sits on the own button")
    assert(relativePoint == "TOPLEFT" and x == 0 and y == 0, "game button sits exactly on the own button")
  end

  -- test_flip_off_builds_native_once_and_replays
  do
    local ctx = wrapPair(true)
    ctx.wrapped.setSelected("b")
    ctx.wrapped.setWidth(300)
    refresh(false)
    assert(called(ctx.native, "setSelected", "b"), "replays the last key")
    assert(called(ctx.native, "setWidth", 300), "replays the width")
    refresh(false)
    assert(ctx.builds == 1, "second refresh builds nothing")
  end

  -- test_replay_uses_picked_key_not_initial
  do
    local ctx = wrapPair(true, { initial = "a" })
    ctx.wrapped.picked("own", "c")
    refresh(false)
    assert(called(ctx.native, "setSelected", "c"), "replays the picked key")
    assert(not called(ctx.native, "setSelected", "a"), "does not replay the initial key")
  end

  -- test_flip_on_shows_own_and_closes_nothing_native
  do
    local ctx = wrapPair(false)
    refresh(true)
    assert(ctx.own.button:IsShown(), "flip on: own button shown")
    assert(not ctx.native.row:IsShown(), "flip on: game dropdown hidden")
  end

  -- test_flip_off_closes_own_list
  do
    local ctx = wrapPair(true)
    refresh(false)
    assert(ctx.closes == 1, "own list closed once when the game dropdown shows")
  end

  -- test_pick_calls_on_change_once_and_mirrors
  do
    local ctx = wrapPair(false)
    ctx.wrapped.picked("native", "d")
    assert(#ctx.changes == 1 and ctx.changes[1] == "d", "onChange once with the picked key")
    assert(called(ctx.own, "setSelected", "d"), "own side mirrors the pick")
  end

  -- test_revert_in_on_change_after_game_pick_wins_on_both_sides
  do
    local ctx = wrapPair(false, { onChange = revertTo("keep") })
    ctx.wrapped.picked("native", "d")
    assert(last(ctx.own, "setSelected") == "keep", "own side keeps the reverted key")
    assert(last(ctx.native, "setSelected") == "keep", "game side keeps the reverted key")
  end

  -- test_revert_in_on_change_after_own_pick_wins_on_both_sides
  do
    local ctx = wrapPair(false, { onChange = revertTo("keep") })
    refresh(true)
    ctx.wrapped.picked("own", "e")
    refresh(false)
    assert(last(ctx.own, "setSelected") == "keep", "own side keeps the reverted key")
    assert(last(ctx.native, "setSelected") == "keep", "game side shows the reverted key")
  end

  -- test_own_pick_reaches_game_side_when_it_shows
  do
    local ctx = wrapPair(false)
    refresh(true)
    ctx.wrapped.picked("own", "e")
    assert(not ctx.native.row:IsShown(), "the pick leaves the game dropdown hidden")
    refresh(false)
    assert(last(ctx.native, "setSelected") == "e", "game side shows the pick once it shows")
  end

  -- test_hidden_game_side_gets_no_calls
  do
    local ctx = wrapPair(false)
    refresh(true)
    local before = #ctx.native.calls
    ctx.wrapped.setSelected("f")
    ctx.wrapped.setOptionsList(LIST)
    ctx.wrapped.setWidth(250)
    ctx.wrapped.applyTheme("dark", COLORS)
    ctx.wrapped.picked("own", "g")
    assert(#ctx.native.calls == before, "no call reaches the hidden game dropdown")
    assert(last(ctx.own, "setWidth") == 250, "own side still gets every call")
    refresh(false)
    assert(last(ctx.native, "setSelected") == "g", "shown game side gets the latest key")
    assert(last(ctx.native, "setOptionsList") == LIST, "shown game side gets the latest list")
    assert(last(ctx.native, "setWidth") == 250, "shown game side gets the latest width")
    assert(last(ctx.native, "applyTheme") == "dark", "shown game side gets the latest theme")
  end

  -- test_shown_game_side_is_not_replayed_twice
  do
    local ctx = wrapPair(false)
    ctx.wrapped.setWidth(260)
    local before = #ctx.native.calls
    refresh(false)
    assert(#ctx.native.calls == before, "a refresh with no flip calls nothing")
  end

  -- test_theme_before_game_side_exists_is_replayed_on_build
  do
    local ctx = wrapPair(true)
    ctx.wrapped.applyTheme("dark", COLORS)
    refresh(false)
    local themed
    for _, call in ipairs(ctx.native.calls) do
      if call.name == "applyTheme" then
        themed = call
      end
    end
    assert(themed and themed[1] == "dark" and themed[2] == COLORS, "theme and colors replayed on build")
  end

  -- test_options_list_with_pad_on_is_replayed_on_first_show
  do
    local ctx = wrapPair(true)
    ctx.wrapped.setOptionsList(LIST)
    refresh(false)
    assert(called(ctx.native, "setOptionsList", LIST), "list replayed on the first show")
  end

  -- test_native_build_failure_keeps_own
  do
    local ctx = wrapPair(false, { fail = true })
    assert(ctx.own.button:IsShown(), "failed build: own button shown")
    refresh(true)
    refresh(false)
    assert(ctx.own.button:IsShown(), "failed build: own button still shown")
    assert(ctx.builds == 1, "failed build never retried")
  end

  -- test_label_set_text_shows_in_both_modes
  do
    local ctx = wrapPair(true)
    ctx.wrapped.label:SetText("X")
    refresh(false)
    assert(ctx.wrapped.label:IsShown(), "label shown with the game dropdown")
    assert(ctx.wrapped.label:GetText() == "X", "label keeps its text")
  end
end

local function createTest()
  -- test_create_close_own_list_hides_the_own_menu
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local menu = factory.CreateFrame("Frame", nil, parent)
  menu:Show()
  local options = {
    initial = "a",
    onChange = function() end,
  }
  local ownOptions
  local savedCreate = NativeDropdown.Create
  NativeDropdown.Create = function(fakeFactory, nativeParent)
    return fakeHandle(fakeFactory, nativeParent)
  end
  local ok, err = pcall(function()
    Flavor.WithPadUI(true, function()
      DropdownSwap.Create(factory, parent, options, function(ownFactory, ownParent, opts)
        ownOptions = opts
        return fakeHandle(ownFactory, ownParent), menu
      end)
    end)
    refresh(false)
  end)
  NativeDropdown.Create = savedCreate
  if not ok then
    error(err, 0)
  end
  assert(menu:IsShown() == false, "own menu hidden when the game dropdown shows")
  assert(type(ownOptions.onChange) == "function", "own builder gets an onChange")
  assert(ownOptions.onChange ~= options.onChange, "own builder's onChange is the swap's, not the caller's")
end

local function appliesTest()
  -- test_applies_only_on_forever_with_hud_on
  Flavor.With(true, true, function()
    withHud("classic", function()
      assert(DropdownSwap.Applies() == true, "Forever + HUD on applies")
    end)
    withHud("off", function()
      assert(DropdownSwap.Applies() == false, "Forever + HUD off does not apply")
    end)
  end)
  Flavor.With(true, false, function()
    withHud("classic", function()
      assert(DropdownSwap.Applies() == false, "Retail + HUD on does not apply")
    end)
  end)
end

return function()
  onForever(wrapTests)
  onForever(createTest)
  appliesTest()
end
