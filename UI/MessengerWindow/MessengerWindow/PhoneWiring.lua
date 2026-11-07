local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local PhoneSlide = ns.MessengerWindowPhoneSlide or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneSlide")
local PhoneNavigator = ns.MessengerWindowPhoneNavigator or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneNavigator")
local PhoneDock = ns.MessengerWindowPhoneDock or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDock")
local PhoneDockFlow = ns.MessengerWindowPhoneDockFlow or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDockFlow")
local WindowGrowAnimation = ns.MessengerWindowWindowGrowAnimation
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGrowAnimation")

-- Everything MessengerWindow asks of the phone layout. Hooks() returns the
-- calls it makes while building, which do nothing until Attach fills them in,
-- and for the whole session in the classic layout.
local PhoneWiring = {}

function PhoneWiring.Hooks()
  return {
    onSelection = function(_key) end,
    onCoverChanged = function(_covered) end,
    onPanesShown = function() end,
    onBack = function()
      return false
    end,
    isListView = function()
      return false
    end,
    dock = function() end,
    onStrataChanged = function(_strata) end,
    isWindowPart = function(_candidate)
      return false
    end,
    resetWindow = function() end,
    showList = function() end,
    isWide = function()
      return false
    end,
  }
end

-- The window's position callbacks. A wide window (settings over the phone
-- layout) is never the saved size. Both are safe with the idle hooks.
function PhoneWiring.WrapPosition(hooks, options)
  local function onPositionChanged(nextState)
    if options.onPositionChanged and not hooks.isWide() then
      options.onPositionChanged(nextState)
    end
  end
  local function onResetWindowPosition()
    local nextState = options.onResetWindowPosition and options.onResetWindowPosition()
    hooks.resetWindow()
    return nextState
  end
  return onPositionChanged, onResetWindowPosition
end

local function windowSize(frame)
  return frame:GetWidth(), frame:GetHeight()
end

local function wideWidth(frame)
  local parent = frame:GetParent() or _G.UIParent
  local _, _, maxWidth = WindowBounds.GetResizeBounds(parent, Theme, frame:GetScale(), false, true)
  return math.min(Theme.WINDOW_WIDTH, maxWidth or Theme.WINDOW_WIDTH)
end

-- options: factory, frame, layout, chrome, tabToggle, composerInput,
-- windowAlpha, windowVisibility,
-- windowOptions (MessengerWindow.Create options), settingsConfig,
-- getSelectedKey(), refreshSelection(state), applyWindowSize(w, h),
-- onPositionChanged(state) (from WrapPosition), buildState(frame).
function PhoneWiring.Attach(hooks, options)
  local frame = options.frame
  local layout = options.layout
  local chrome = options.chrome
  local tabToggle = options.tabToggle
  local windowOptions = options.windowOptions
  local getDockIcon = windowOptions.getDockIcon or function()
    return nil
  end
  local restoreWidth, restoreHeight = nil, nil

  local function isCovered()
    return not options.windowVisibility.isConversationPaneShown()
  end

  local slide = PhoneSlide.Create({ layout = layout, theme = Theme, isCovered = isCovered })
  local openAnimation = WindowGrowAnimation.Attach(frame, {
    factory = options.factory,
    parent = frame:GetParent() or _G.UIParent,
    theme = Theme,
    setAlphaHeld = options.windowAlpha.setHeld,
    refreshAlpha = function()
      options.windowAlpha.refreshWindowAlpha(true)
    end,
  })

  local navigator = PhoneNavigator.Create({
    slide = slide,
    isAnimatable = function()
      return frame:IsShown() and not isCovered()
    end,
    onChatView = function(inChat)
      chrome.setPhoneChatView(inChat)
    end,
    getSelectedKey = options.getSelectedKey,
    clearSelection = function()
      if windowOptions.onSelectConversation then
        windowOptions.onSelectConversation(nil)
      else
        options.refreshSelection({})
      end
    end,
    focusChat = function()
      local input = options.composerInput
      if options.settingsConfig.autoFocusComposer == true and input and input.SetFocus then
        input:SetFocus()
      end
    end,
  })
  -- Under a cover no chat is on screen to leave: same guard as the back arrow.
  local function backUnlessCovered()
    return not isCovered() and navigator.back()
  end
  if tabToggle and tabToggle.setCurrentModeClickHandler then
    tabToggle.setCurrentModeClickHandler(backUnlessCovered)
  end

  local rideHandlers = {
    beginDrag = function()
      frame:StartMoving()
    end,
    endDrag = function()
      frame:StopMovingOrSizing()
      options.onPositionChanged(options.buildState(frame))
    end,
  }

  -- A window opening for the first time may have no position until next frame.
  local function clampToSpot()
    if PhoneDock.ClampToSpot(frame, chrome.iconSlot) then
      return
    end
    local timer = _G.C_Timer
    if type(timer) == "table" and type(timer.After) == "function" then
      timer.After(0, function()
        PhoneDock.ClampToSpot(frame, chrome.iconSlot)
      end)
    end
  end

  local getGrowSource = windowOptions.getGrowSource or function()
    return nil
  end
  local isGrowAnimationOn = windowOptions.isGrowAnimationOn or function()
    return true
  end
  local flow = PhoneDockFlow.Attach(frame, {
    chrome = chrome,
    getDockIcon = getDockIcon,
    openAnimation = openAnimation,
    rideHandlers = rideHandlers,
    getGrowSource = getGrowSource,
    isGrowAnimationOn = isGrowAnimationOn,
  })

  hooks.onSelection = navigator.syncSelection
  hooks.onPanesShown = slide.settle
  hooks.isListView = navigator.isListView
  hooks.showList = navigator.showList
  hooks.dock = flow.dock
  hooks.onStrataChanged = function(strata)
    flow.setStrata(strata)
  end
  hooks.isWindowPart = flow.isWindowPart
  hooks.isWide = function()
    return layout.phoneWide == true
  end

  hooks.onBack = backUnlessCovered

  -- Settings and addon panels are laid out for a wide window; it grows away
  -- from the button while they show and returns after.
  hooks.onCoverChanged = function(covered)
    covered = covered == true
    if covered == (layout.phoneWide == true) then
      return
    end
    layout.phoneWide = covered
    if covered then
      restoreWidth, restoreHeight = windowSize(frame)
      options.applyWindowSize(wideWidth(frame), restoreHeight)
      return
    end
    options.applyWindowSize(restoreWidth, restoreHeight)
  end

  hooks.resetWindow = function()
    local L = Theme.LAYOUT
    if layout.phoneWide then
      restoreWidth, restoreHeight = L.PHONE_WINDOW_WIDTH, L.PHONE_WINDOW_HEIGHT
    else
      options.applyWindowSize(L.PHONE_WINDOW_WIDTH, L.PHONE_WINDOW_HEIGHT)
    end
    PhoneDock.Center(frame)
  end

  frame:HookScript("OnShow", clampToSpot)
  frame:HookScript("OnShow", flow.open)
  frame:HookScript("OnShow", flow.syncIconSlot)
  frame:HookScript("OnHide", function()
    -- A hidden viewport stops ticking, which would leave a slide hanging.
    slide.finishNow()
    flow.close()
  end)

  local selectedKey = options.getSelectedKey()
  if selectedKey ~= nil then
    navigator.syncSelection(selectedKey)
  else
    slide.snapTo(0)
  end
end

ns.MessengerWindowPhoneWiring = PhoneWiring

return PhoneWiring
