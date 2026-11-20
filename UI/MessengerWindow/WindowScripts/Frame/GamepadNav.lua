local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local GamepadDeps = ns.MessengerWindowGamepadDeps or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadDeps")
local Constants = ns.Constants or require("WhisperMessenger.Core.Constants")
local GamepadMarks = ns.MessengerWindowGamepadMarks or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadMarks")
local GamepadPopups = ns.MessengerWindowGamepadPopups or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadPopups")
local GamepadRightClick = ns.MessengerWindowGamepadRightClick or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadRightClick")

-- The one place that talks to the game's gamepad UI
-- (GamepadMode.FrameControlsManager and SmartNavigation) for the messenger
-- window and its popups. On a client without that API (today: every flavor
-- but WoW: Forever) every method does nothing.
-- Nothing calls into that UI in combat: what was asked for then is done
-- when combat ends.
local GamepadNav = {}

-- Targets with this buttonContext open their right-click menu with X.
GamepadNav.RIGHT_CLICK_CONTEXT = Constants.GAMEPAD_RIGHT_CLICK_CONTEXT

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
    markFocusable = noop,
    setStepper = noop,
    setEdgeOverride = noop,
    popupShown = noop,
    popupHidden = noop,
    setPopupCloseHandler = noop,
    bindRightClick = noop,
    isActive = never,
    isRegistered = never,
  }
end

-- frame: the messenger window. deps (all optional): hasGamepadUI,
-- gamepadMode, smartNavigation, markIgnored, markFocusable, addJumpOverride,
-- directions, inCombat, after, createFrame, gamepadSharedUtility,
-- rightClickKey, promptedBindingMixin; default to the game's.
function GamepadNav.New(frame, deps)
  deps = deps or {}
  local pick = GamepadDeps.pick
  local hasGamepadUI = pick(deps, "hasGamepadUI", FlavorCompat.HasGamepadUI())
  local gamepadMode = pick(deps, "gamepadMode", _G.GamepadMode)
  local smartNavigation = pick(deps, "smartNavigation", _G.SmartNavigation)
  local fcm = type(gamepadMode) == "table" and gamepadMode.FrameControlsManager or nil
  if not hasGamepadUI or type(fcm) ~= "table" or type(fcm.FrameShown) ~= "function" or type(smartNavigation) ~= "table" then
    return inert()
  end
  local markIgnored = pick(deps, "markIgnored", _G.SmartNavigation_MarkFrameIgnored)
  local markFocusable = pick(deps, "markFocusable", _G.SmartNavigation_MarkFrameFocusable)
  local addJumpOverride = pick(deps, "addJumpOverride", _G.SmartNavigation_AddJumpNavigationOverride)
  local directions = pick(deps, "directions", _G.SMART_NAV_INPUT_DIRECTION)
  local inCombat = pick(deps, "inCombat", GamepadDeps.defaultInCombat)
  local after = pick(deps, "after", GamepadDeps.defaultAfter)
  local createFrame = pick(deps, "createFrame", GamepadDeps.defaultCreateFrame)

  local nav = {}
  local registered, shown = false, false
  local refreshScheduled = false
  local pendingRegister, pendingHide, pendingRefresh, pendingScroll = false, false, false, false
  local scrollTarget, scrollCallbackSet = nil, false
  local marks = GamepadMarks.New({
    inCombat = inCombat,
    markIgnored = markIgnored,
    markFocusable = markFocusable,
    addJumpOverride = addJumpOverride,
    directions = directions,
  })
  local popups = GamepadPopups.New({ fcm = fcm, inCombat = inCombat })
  local mixin = pick(deps, "promptedBindingMixin", _G.PromptedBindingMixin)
  local rightClick = GamepadRightClick.New(frame, {
    sharedUtility = pick(deps, "gamepadSharedUtility", _G.GamepadSharedUtility),
    key = pick(deps, "rightClickKey", _G.GAMEPAD_FACE_LEFT),
    onlyIfUsable = mixin and mixin.VISIBILITY_TYPE and mixin.VISIBILITY_TYPE.ONLY_IF_USABLE,
    smartNavigation = smartNavigation,
  })

  local function register()
    local result = fcm:FrameShown(frame)
    if result == false then
      fcm:FrameHidden(frame)
      result = fcm:FrameShown(frame)
    end
    registered = result == true
    if registered then
      rightClick.show()
    end
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

  -- Combat over: queued marks, then the pending hide or re-register,
  -- then the scroll frame the game asked for meanwhile, then our popups
  -- (after the window: it is their return frame), then one re-scan if one
  -- was asked for meanwhile.
  local function settle()
    if inCombat() then
      after(0, settle)
      return
    end
    marks.settle()
    if registered and (pendingHide or pendingRegister) then
      fcm:FrameHidden(frame)
      registered = false
      rightClick.hide()
    end
    pendingHide = false
    if pendingRegister then
      pendingRegister = false
      if shown then
        register()
      end
    end
    if pendingScroll then
      pendingScroll = false
      if registered and smartNavigation:GetPanelInfo(frame, true) ~= nil then
        smartNavigation:SetScrollFrameForFrame(frame, scrollTarget)
      end
    end
    -- Back on after combat (or a bind made in combat); idempotent.
    if registered then
      rightClick.show()
    end
    popups.settle()
    if pendingRefresh then
      pendingRefresh = false
      rescan()
    end
  end

  local eventFrame = createFrame and createFrame()
  if eventFrame then
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    -- PLAYER_REGEN_DISABLED runs before lockdown: X goes off for combat.
    eventFrame:SetScript("OnEvent", function(_, event)
      if event == "PLAYER_REGEN_DISABLED" then
        rightClick.hide()
      else
        settle()
      end
    end)
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
    rightClick.hide()
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

  local function applyScrollTarget()
    if inCombat() then
      pendingScroll = true
      return
    end
    pendingScroll = false
    smartNavigation:SetScrollFrameForFrame(frame, scrollTarget)
  end

  -- The right stick scrolls the latest scrollFrame: at once when the game
  -- knows the window, else once it does.
  function nav.setScrollFrame(scrollFrame)
    scrollTarget = scrollFrame
    if not scrollCallbackSet then
      scrollCallbackSet = true
      smartNavigation:SetSmartNavPanelInfoAddedCallback(frame, applyScrollTarget)
    end
    if registered and smartNavigation:GetPanelInfo(frame, true) ~= nil then
      applyScrollTarget()
    end
  end

  -- X right-clicks the focused target carrying buttonContext; label is
  -- its prompt. The first call wins.
  function nav.bindRightClick(buttonContext, label)
    if rightClick.bind(buttonContext, label) and eventFrame then
      eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    end
    if registered and not inCombat() then
      rightClick.show()
    end
  end

  nav.ignore = marks.ignore
  nav.markFocusable = marks.markFocusable
  nav.setStepper = marks.setStepper
  nav.setEdgeOverride = marks.setEdgeOverride
  nav.popupShown = popups.popupShown
  nav.popupHidden = popups.popupHidden
  nav.setPopupCloseHandler = popups.setPopupCloseHandler

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
