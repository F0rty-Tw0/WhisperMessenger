-- A DropdownSwap pair over fake handles: the own side and, once built, the
-- game's side record every setter call.
local FakeUI = require("tests.helpers.fake_ui")
local Flavor = require("tests.helpers.flavor")
local DropdownSwap = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSwap")

local SwapPair = {}

local function recorder(calls, name)
  return function(...)
    calls[#calls + 1] = { name = name, ... }
  end
end

-- Handle like DropdownSelector's and NativeDropdown's; setters record calls.
-- Fake frames start hidden, so show row, label and button as WoW would.
function SwapPair.FakeHandle(factory, parent)
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

function SwapPair.Called(handle, name, value)
  for _, call in ipairs(handle.calls) do
    if call.name == name and call[1] == value then
      return true
    end
  end
  return false
end

-- The first argument of the last `name` call, or nil.
function SwapPair.Last(handle, name)
  for i = #handle.calls, 1, -1 do
    if handle.calls[i].name == name then
      return handle.calls[i][1]
    end
  end
  return nil
end

-- Wraps a fake own handle with the pad UI `padOn`; `opts.fail` makes the
-- game's dropdown fail to build; `opts.onChange(ctx, key)` runs inside the
-- pair's onChange after the key is recorded.
function SwapPair.Wrap(padOn, opts)
  opts = opts or {}
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local ctx = { own = SwapPair.FakeHandle(factory, parent), builds = 0, closes = 0, changes = {} }
  local function buildNative()
    ctx.builds = ctx.builds + 1
    if opts.fail then
      return nil
    end
    ctx.native = SwapPair.FakeHandle(factory, ctx.own.row)
    return ctx.native
  end
  local function onChange(key)
    ctx.changes[#ctx.changes + 1] = key
    if opts.onChange then
      opts.onChange(ctx, key)
    end
  end
  local function closeOwnList()
    ctx.closes = ctx.closes + 1
  end
  Flavor.WithPadUI(padOn, function()
    ctx.wrapped = DropdownSwap.Wrap(ctx.own, buildNative, onChange, closeOwnList, opts.initial)
  end)
  return ctx
end

function SwapPair.Refresh(padOn)
  Flavor.WithPadUI(padOn, DropdownSwap.Refresh)
end

return SwapPair
