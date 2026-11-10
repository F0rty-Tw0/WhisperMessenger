local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local WindowBounds = ns.MessengerWindowWindowBounds or require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local CompactSlide = ns.MessengerWindowCompactSlide or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.CompactSlide")
local CompactNavigator = ns.MessengerWindowCompactNavigator or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.CompactNavigator")
local CompactDock = ns.MessengerWindowCompactDock or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.CompactDock")

-- Everything MessengerWindow asks of the compact layout. Hooks() returns the
-- calls it makes while building, which do nothing until Attach fills them in,
-- and for the whole session in the classic layout.
local CompactWiring = {}

function CompactWiring.Hooks()
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
    resetWindow = function() end,
    applyWhenNarrow = function(_state) end,
    showList = function() end,
    isWide = function()
      return false
    end,
  }
end

-- The window's position callbacks. A wide window (settings over the compact
-- layout) is never the saved size. Both are safe with the idle hooks.
function CompactWiring.WrapPosition(hooks, options)
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

-- options: frame, layout, chrome, tabToggle, composerInput, windowVisibility,
-- windowOptions (MessengerWindow.Create options), settingsConfig,
-- getSelectedKey(), refreshSelection(state), applyWindowSize(w, h),
-- applyPending(state) (a saved state held while the window was wide).
-- The floating button's dock is DockWiring's, in both layouts.
function CompactWiring.Attach(hooks, options)
  local frame = options.frame
  local layout = options.layout
  local chrome = options.chrome
  local tabToggle = options.tabToggle
  local windowOptions = options.windowOptions
  local restoreWidth, restoreHeight = nil, nil
  local pendingState = nil

  local function isCovered()
    return not options.windowVisibility.isConversationPaneShown()
  end

  local slide = CompactSlide.Create({ layout = layout, theme = Theme, isCovered = isCovered })

  local navigator = CompactNavigator.Create({
    slide = slide,
    isAnimatable = function()
      return frame:IsShown() and not isCovered() and options.settingsConfig.windowAnimation ~= false
    end,
    onChatView = function(inChat)
      chrome.setCompactChatView(inChat)
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

  hooks.onSelection = navigator.syncSelection
  hooks.onPanesShown = slide.settle
  hooks.isListView = navigator.isListView
  hooks.showList = navigator.showList
  hooks.isWide = function()
    return layout.compactWide == true
  end

  hooks.onBack = backUnlessCovered

  -- covered here means the wide window is needed: the options pane or a panel
  -- that is not compact shows. The window grows away from the button
  -- meanwhile and returns after. (Compact panels cover the chat but keep the
  -- narrow window.)
  hooks.onCoverChanged = function(covered)
    covered = covered == true
    if covered == (layout.compactWide == true) then
      return
    end
    layout.compactWide = covered
    if covered then
      restoreWidth, restoreHeight = windowSize(frame)
      options.applyWindowSize(wideWidth(frame), restoreHeight)
      return
    end
    options.applyWindowSize(restoreWidth, restoreHeight)
    local state = pendingState
    pendingState = nil
    if state and options.applyPending then
      options.applyPending(state)
    end
  end

  -- Only called while wide: the state waits for the narrow window, newest wins.
  hooks.applyWhenNarrow = function(state)
    pendingState = state
  end

  hooks.resetWindow = function()
    local L = Theme.LAYOUT
    pendingState = nil
    if layout.compactWide then
      restoreWidth, restoreHeight = L.COMPACT_WINDOW_WIDTH, L.COMPACT_WINDOW_HEIGHT
    else
      options.applyWindowSize(L.COMPACT_WINDOW_WIDTH, L.COMPACT_WINDOW_HEIGHT)
    end
    CompactDock.Center(frame)
  end

  frame:HookScript("OnHide", function()
    -- A hidden viewport stops ticking, which would leave a slide hanging.
    slide.finishNow()
  end)

  local selectedKey = options.getSelectedKey()
  if selectedKey ~= nil then
    navigator.syncSelection(selectedKey)
  else
    slide.snapTo(0)
  end
end

ns.MessengerWindowCompactWiring = CompactWiring

return CompactWiring
