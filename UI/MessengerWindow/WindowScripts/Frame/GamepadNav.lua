local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

-- The one place that talks to the WoW: Forever gamepad UI
-- (GamepadMode.FrameControlsManager and SmartNavigation) for the messenger
-- window. Off Forever, or without that UI, every method does nothing.
-- Nothing calls into that UI in combat: what was asked for then is done
-- when combat ends.
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
---@generic T
---@param deps table
---@param field string
---@param default T
---@return T
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

local function defaultInCombat()
  local restrictions = _G.C_RestrictedActions
  local types = _G.Enum and _G.Enum.AddOnRestrictionType
  if type(restrictions) == "table" and type(restrictions.IsAddOnRestrictionActive) == "function" and types and types.Combat ~= nil then
    return restrictions.IsAddOnRestrictionActive(types.Combat) == true
  end
  local inCombatLockdown = _G.InCombatLockdown
  return type(inCombatLockdown) == "function" and inCombatLockdown() == true
end

local function defaultAfter(delay, fn)
  _G.C_Timer.After(delay, fn)
end

local function defaultCreateFrame()
  return _G.CreateFrame("Frame")
end

-- frame: the messenger window. deps (all optional): isForever, gamepadMode,
-- smartNavigation, markIgnored, inCombat, after, createFrame; default to the
-- game's.
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
  local inCombat = pick(deps, "inCombat", defaultInCombat)
  local after = pick(deps, "after", defaultAfter)
  local createFrame = pick(deps, "createFrame", defaultCreateFrame)

  local nav = {}
  local registered, shown = false, false
  local refreshScheduled = false
  local pendingRegister, pendingHide, pendingRefresh = false, false, false
  local ignored = setmetatable({}, { __mode = "k" })
  local ignoreQueue = {}

  local function register()
    local result = fcm:FrameShown(frame)
    if result == false then
      fcm:FrameHidden(frame)
      result = fcm:FrameShown(frame)
    end
    registered = result == true
  end

  local function rescan()
    if registered and smartNavigation:GetPanelInfo(frame, true) ~= nil then
      smartNavigation:RefreshButtonGroups(frame)
    end
  end

  local function runRefresh()
    refreshScheduled = false
    if inCombat() then
      pendingRefresh = true
      return
    end
    rescan()
  end

  -- Combat over: queued ignores, then the pending hide or re-register,
  -- then one re-scan if one was asked for meanwhile.
  local function settle()
    if inCombat() then
      after(0, settle)
      return
    end
    local queue = ignoreQueue
    ignoreQueue = {}
    for _, entry in ipairs(queue) do
      markIgnored(entry.widget, entry.dontPropagate)
    end
    if registered and (pendingHide or pendingRegister) then
      fcm:FrameHidden(frame)
      registered = false
    end
    pendingHide = false
    if pendingRegister then
      pendingRegister = false
      if shown then
        register()
      end
    end
    if pendingRefresh then
      pendingRefresh = false
      rescan()
    end
  end

  local eventFrame = createFrame and createFrame()
  if eventFrame then
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:SetScript("OnEvent", settle)
  end

  function nav.onShow()
    shown = true
    if inCombat() then
      pendingRegister = true
      return
    end
    pendingHide = false
    register()
  end

  function nav.onHide()
    shown = false
    pendingRegister = false
    if not registered then
      return
    end
    if inCombat() then
      pendingHide = true
      return
    end
    pendingHide = false
    fcm:FrameHidden(frame)
    registered = false
  end

  -- Re-scan the window's buttons on the next frame, once however often asked.
  function nav.refresh()
    if not registered then
      return
    end
    if inCombat() then
      pendingRefresh = true
      return
    end
    if refreshScheduled then
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
      if not inCombat() then
        smartNavigation:SetScrollFrameForFrame(frame, scrollFrame)
      end
    end)
  end

  -- The D-pad skips widget (and its children unless dontPropagate).
  function nav.ignore(widget, dontPropagate)
    if widget == nil or ignored[widget] or not markIgnored then
      return
    end
    ignored[widget] = true
    if inCombat() then
      table.insert(ignoreQueue, { widget = widget, dontPropagate = dontPropagate })
      return
    end
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
