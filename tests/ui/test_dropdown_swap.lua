-- On WoW: Forever a settings dropdown pairs WM's own list with the game's
-- dropdown and shows the one that fits the gamepad UI: WM's own while the
-- pad UI is on, the game's while it is off.
local FakeUI = require("tests.helpers.fake_ui")
local Flavor = require("tests.helpers.flavor")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local NativeDropdown = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.NativeDropdown")
local DropdownSwap = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSwap")

local function recorder(calls, name)
  return function(...)
    calls[#calls + 1] = { name = name, ... }
  end
end

-- Handle like DropdownSelector's and NativeDropdown's; setters record calls.
-- Fake frames start hidden, so show row, label and button as WoW would.
local function fakeHandle(factory, parent)
  local row = factory.CreateFrame("Frame", nil, parent)
  local calls = {}
  local handle = {
    row = row,
    label = row:CreateFontString(nil, "OVERLAY"),
    button = factory.CreateFrame("Button", nil, row),
    calls = calls,
    setSelected = recorder(calls, "setSelected"),
    setOptionsList = recorder(calls, "setOptionsList"),
    setWidth = recorder(calls, "setWidth"),
    applyTheme = recorder(calls, "applyTheme"),
  }
  handle.row:Show()
  handle.label:Show()
  handle.button:Show()
  return handle
end

local function called(handle, name, value)
  for _, call in ipairs(handle.calls) do
    if call.name == name and call[1] == value then
      return true
    end
  end
  return false
end

-- Wraps a fake own handle with the pad UI `padOn`; `opts.fail` makes the
-- game's dropdown fail to build.
local function wrapPair(padOn, opts)
  opts = opts or {}
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local ctx = { own = fakeHandle(factory, parent), builds = 0, closes = 0, changes = {} }
  local function buildNative()
    ctx.builds = ctx.builds + 1
    if opts.fail then
      return nil
    end
    ctx.native = fakeHandle(factory, ctx.own.row)
    return ctx.native
  end
  local function onChange(key)
    ctx.changes[#ctx.changes + 1] = key
  end
  local function closeOwnList()
    ctx.closes = ctx.closes + 1
  end
  Flavor.WithPadUI(padOn, function()
    ctx.wrapped = DropdownSwap.Wrap(ctx.own, buildNative, onChange, closeOwnList, opts.initial)
  end)
  return ctx
end

local function refresh(padOn)
  Flavor.WithPadUI(padOn, DropdownSwap.Refresh)
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

  -- test_mirror_does_not_show_hidden_side
  do
    local ctx = wrapPair(false)
    refresh(true)
    ctx.wrapped.picked("own", "e")
    assert(called(ctx.native, "setSelected", "e"), "game side mirrors the pick")
    assert(not ctx.native.row:IsShown(), "mirror leaves the game dropdown hidden")
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

  -- test_registry_drops_nothing_while_row_lives
  do
    -- Only the own row and button outlive this call; the handle does not.
    local function wrapKeepingRow()
      local ctx = wrapPair(true)
      return ctx.own.row, ctx.own.button
    end
    local ownRow, ownButton = wrapKeepingRow()
    collectgarbage()
    collectgarbage()
    refresh(false)
    assert(ownRow ~= nil, "row kept by the test")
    assert(not ownButton:IsShown(), "registered pair still swaps")
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
