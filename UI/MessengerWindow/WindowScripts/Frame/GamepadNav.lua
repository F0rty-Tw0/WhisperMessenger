local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

-- The one place that talks to the WoW: Forever gamepad UI
-- (GamepadMode.FrameControlsManager and SmartNavigation) for the messenger
-- window. Off Forever, or without that UI, every method does nothing.
local GamepadNav = {}

local function noop() end

local function never()
  return false
end

local function inert()
  return {
    onShow = noop,
    onHide = noop,
    refresh = noop,
    setCloseHandler = noop,
    setScrollFrame = noop,
    ignore = noop,
    isActive = never,
    isRegistered = never,
  }
end

-- A dep given as false counts as absent: no fallback to the default.
local function pick(deps, field, default)
  local value = deps[field]
  if value == nil then
    return default
  end
  if value == false then
    return nil
  end
  return value
end

local function defaultAfter(delay, fn)
  _G.C_Timer.After(delay, fn)
end

-- frame: the messenger window. deps (all optional): isForever, gamepadMode,
-- smartNavigation, markIgnored, after; default to the game's.
function GamepadNav.New(frame, deps)
  deps = deps or {}
  local isForever = pick(deps, "isForever", FlavorCompat.isForever)
  local gamepadMode = pick(deps, "gamepadMode", _G.GamepadMode)
  local smartNavigation = pick(deps, "smartNavigation", _G.SmartNavigation)
  local fcm = type(gamepadMode) == "table" and gamepadMode.FrameControlsManager or nil
  if not isForever or type(fcm) ~= "table" or type(fcm.FrameShown) ~= "function" or type(smartNavigation) ~= "table" then
    return inert()
  end
  local markIgnored = pick(deps, "markIgnored", _G.SmartNavigation_MarkFrameIgnored)
  local after = pick(deps, "after", defaultAfter)

  local nav = {}
  local registered = false
  local refreshScheduled = false
  local ignored = setmetatable({}, { __mode = "k" })

  local function register()
    local result = fcm:FrameShown(frame)
    if result == false then
      fcm:FrameHidden(frame)
      result = fcm:FrameShown(frame)
    end
    registered = result == true
  end

  local function runRefresh()
    refreshScheduled = false
    if registered and smartNavigation:GetPanelInfo(frame, true) ~= nil then
      smartNavigation:RefreshButtonGroups(frame)
    end
  end

  function nav.onShow()
    register()
  end

  function nav.onHide()
    if registered then
      fcm:FrameHidden(frame)
      registered = false
    end
  end

  -- Re-scan the window's buttons on the next frame, once however often asked.
  function nav.refresh()
    if not registered or refreshScheduled then
      return
    end
    refreshScheduled = true
    after(0, runRefresh)
  end

  -- fn() decides what B closes; its result tells the game it was handled.
  function nav.setCloseHandler(fn)
    frame.SmartNavigationCloseHandler = function()
      return fn()
    end
  end

  -- The right stick scrolls scrollFrame once the game knows the window.
  function nav.setScrollFrame(scrollFrame)
    smartNavigation:SetSmartNavPanelInfoAddedCallback(frame, function()
      smartNavigation:SetScrollFrameForFrame(frame, scrollFrame)
    end)
  end

  -- The D-pad skips widget (and its children unless dontPropagate).
  function nav.ignore(widget, dontPropagate)
    if widget == nil or ignored[widget] or not markIgnored then
      return
    end
    ignored[widget] = true
    markIgnored(widget, dontPropagate)
  end

  function nav.isActive()
    return true
  end

  function nav.isRegistered()
    return registered
  end

  return nav
end

ns.MessengerWindowGamepadNav = GamepadNav

return GamepadNav
