local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local PhoneSlide = ns.MessengerWindowPhoneSlide or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneSlide")
local PhoneNavigator = ns.MessengerWindowPhoneNavigator or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneNavigator")
local PhoneDock = ns.MessengerWindowPhoneDock or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDock")
local PhoneOpenAnimation = ns.MessengerWindowPhoneOpenAnimation or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneOpenAnimation")

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
    onWindowMoved = function() end,
    resetSize = function() end,
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
    hooks.onWindowMoved()
    if options.onPositionChanged and not hooks.isWide() then
      options.onPositionChanged(nextState)
    end
  end
  local function onResetWindowPosition()
    local nextState = options.onResetWindowPosition and options.onResetWindowPosition()
    hooks.resetSize()
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
-- getSelectedKey(), refreshSelection(state), applyWindowSize(w, h).
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
  local openAnimation = PhoneOpenAnimation.Attach(frame, {
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
      if tabToggle and tabToggle.setChatView then
        tabToggle.setChatView(inChat)
      end
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

  local rideHandlers = {
    beginDrag = function()
      frame:StartMoving()
    end,
    endDrag = function()
      frame:StopMovingOrSizing()
      hooks.onWindowMoved()
    end,
  }

  -- Already riding (the scale changed, or Alt+Z brought the UI back): the
  -- button only needs its new spot, with no opening to replay.
  local function dock()
    local icon = getDockIcon()
    if not (icon and icon.rideTo and icon.isRiding()) then
      return
    end
    openAnimation.finish()
    icon.rideTo(PhoneDock.RideTarget(chrome.iconSlot, icon.frame))
  end

  -- The button travels onto the window as the window comes out of it.
  local function openFromIcon()
    local icon = getDockIcon()
    if not (icon and icon.rideTo) then
      return
    end
    if icon.isRiding() then
      dock()
      return
    end
    PhoneDock.Place(frame, chrome.iconSlot, icon.frame)
    icon.setRideHandlers(rideHandlers)
    icon.rideTo(PhoneDock.RideTarget(chrome.iconSlot, icon.frame), openAnimation.beginOpen(icon.frame))
  end

  -- Not when only the parent hid (Alt+Z): the window is still open.
  local function undock()
    if frame:IsShown() then
      return
    end
    local icon = getDockIcon()
    if icon and icon.rideHome and icon.isRiding() then
      icon.setRideHandlers(nil)
      icon.rideHome(openAnimation.beginClose(icon.frame))
    end
  end

  hooks.onSelection = navigator.syncSelection
  hooks.onPanesShown = slide.settle
  hooks.isListView = navigator.isListView
  hooks.showList = navigator.showList
  hooks.dock = dock
  hooks.onWindowMoved = function()
    local icon = getDockIcon()
    if icon and icon.isRiding and icon.isRiding() then
      icon.adoptRidePosition()
    end
  end
  hooks.isWide = function()
    return layout.phoneWide == true
  end

  hooks.onBack = function()
    return not isCovered() and navigator.back()
  end

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

  hooks.resetSize = function()
    local L = Theme.LAYOUT
    if layout.phoneWide then
      restoreWidth, restoreHeight = L.PHONE_WINDOW_WIDTH, L.PHONE_WINDOW_HEIGHT
      return
    end
    options.applyWindowSize(L.PHONE_WINDOW_WIDTH, L.PHONE_WINDOW_HEIGHT)
  end

  frame:HookScript("OnShow", openFromIcon)
  frame:HookScript("OnHide", function()
    -- A hidden viewport stops ticking, which would leave a slide hanging.
    slide.finishNow()
    undock()
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
