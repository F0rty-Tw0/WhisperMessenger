local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local NativeDropdown = ns.MessengerWindowNativeDropdown or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.NativeDropdown")

-- On WoW: Forever under the Native look a settings dropdown is a pair:
-- WhisperMessenger's own list (always built) and the game's dropdown (built
-- the first time it must show). The own list shows while the game's gamepad
-- UI is on, the game's dropdown while it is off; Refresh re-picks the side
-- for every pair after the pad UI flips. One handle drives both sides.
local DropdownSwap = {}

-- Keyed by the own row. Pairs live for the session: settings rows are built
-- once.
local pairsByRow = {}

function DropdownSwap.Applies()
  return FlavorCompat.isForever == true and Hud.IsOn()
end

-- Builds the game's side once; a failed build marks the pair and never
-- retries. The game's button takes the own button's place, under the own
-- label.
local function ensureNative(pair)
  if pair.native or pair.nativeFailed then
    return pair.native
  end
  local native = pair.buildNative()
  if not native then
    pair.nativeFailed = true
    return nil
  end
  native.label:Hide()
  native.button:ClearAllPoints()
  native.button:SetPoint("TOPLEFT", pair.own.button, "TOPLEFT", 0, 0)
  pair.native = native
  return native
end

-- Gives the game's side every value the handle got while it was hidden.
local function replay(pair, native)
  if pair.key ~= nil then
    native.setSelected(pair.key)
  end
  if pair.optionsList ~= nil then
    native.setOptionsList(pair.optionsList)
  end
  if pair.width ~= nil then
    native.setWidth(pair.width)
  end
  if pair.themed then
    native.applyTheme(pair.theme, pair.colors)
  end
end

-- With the gamepad UI on no game dropdown is driven: the game's side gets
-- calls only while it shows (pair.nativeShown) and catches up each time it
-- shows again.
local function showSide(pair)
  local native = nil
  if not FlavorCompat.UsesOwnMenus() then
    native = ensureNative(pair)
  end
  if native then
    if pair.closeOwnList then
      pair.closeOwnList()
    end
    pair.own.button:Hide()
    native.row:Show()
    if not pair.nativeShown then
      pair.nativeShown = true
      replay(pair, native)
    end
    return
  end
  pair.nativeShown = false
  pair.own.button:Show()
  if pair.native then
    pair.native.row:Hide()
  end
end

-- Calls `method` on the own side and on the game's side if it shows.
local function forward(pair, method, ...)
  pair.own[method](...)
  if pair.nativeShown then
    pair.native[method](...)
  end
end

function DropdownSwap.Wrap(ownHandle, buildNative, onChange, closeOwnList, initialKey)
  local pair = {
    own = ownHandle,
    buildNative = buildNative,
    closeOwnList = closeOwnList,
    key = initialKey,
  }

  local wrapped = {
    row = ownHandle.row,
    label = ownHandle.label,
    button = ownHandle.button,
    setSelected = function(key)
      pair.key = key
      forward(pair, "setSelected", key)
    end,
    setOptionsList = function(list)
      pair.optionsList = list
      forward(pair, "setOptionsList", list)
    end,
    setWidth = function(width)
      pair.width = width
      forward(pair, "setWidth", width)
    end,
    applyTheme = function(theme, colors)
      pair.theme, pair.colors, pair.themed = theme, colors, true
      forward(pair, "applyTheme", theme, colors)
    end,
    -- A game-side pick is mirrored on the own side, then reported once:
    -- mirroring first lets onChange setSelected another key without the
    -- mirror overwriting it. An own-side pick needs no mirror: the game
    -- side is hidden then and catches up when it shows.
    picked = function(side, key)
      pair.key = key
      if side ~= "own" then
        ownHandle.setSelected(key)
      end
      if onChange then
        onChange(key)
      end
    end,
  }

  pairsByRow[ownHandle.row] = pair
  showSide(pair)
  return wrapped
end

-- Shallow copy of `options` with onChange replaced.
local function withOnChange(options, onChange)
  local copy = {}
  for key, value in pairs(options) do
    copy[key] = value
  end
  copy.onChange = onChange
  return copy
end

-- `buildOwn(factory, parent, options) -> ownHandle, menu` builds the own
-- list; the game's dropdown is built inside the own row when it must show.
function DropdownSwap.Create(factory, parent, options, buildOwn)
  options = options or {}
  local wrapped
  local ownHandle, menu = buildOwn(
    factory,
    parent,
    withOnChange(options, function(key)
      wrapped.picked("own", key)
    end)
  )
  local function buildNative()
    return NativeDropdown.Create(
      factory,
      ownHandle.row,
      withOnChange(options, function(key)
        wrapped.picked("native", key)
      end)
    )
  end
  local function closeOwnList()
    if menu and menu:IsShown() then
      menu:Hide()
    end
  end
  wrapped = DropdownSwap.Wrap(ownHandle, buildNative, options.onChange, closeOwnList, options.initial)
  return wrapped
end

function DropdownSwap.Refresh()
  for _, pair in pairs(pairsByRow) do
    showSide(pair)
  end
end

ns.MessengerWindowDropdownSwap = DropdownSwap
return DropdownSwap
