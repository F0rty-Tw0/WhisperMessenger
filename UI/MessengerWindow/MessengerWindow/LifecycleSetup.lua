local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local LifecycleWiring = ns.MessengerWindowLifecycleWiring or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.LifecycleWiring")

-- Hands the parts MessengerWindow.Create built so far to LifecycleWiring:
-- window scripts, resize, the contacts divider, ESC and saved state.
local LifecycleSetup = {}

local function isShown(target)
  if target and target.IsShown then
    return target:IsShown()
  end
  return target ~= nil and target.shown == true
end

-- parts: composerRuntime, contactsRuntime, conversation, panelWiring,
-- compactMode, dock, edge, getSelectedConversationKey, onResetWindowPosition,
-- onPositionChanged, getContactsRail (built after this, read at call time).
-- Returns relayoutWindow, scriptResult.
function LifecycleSetup.Run(shell, options, parts)
  local settingsConfig, windowGeometry = shell.settingsConfig, shell.windowGeometry
  local currentContactsWidth = shell.contactsWidth
  local composerRuntime, contactsRuntime = parts.composerRuntime, parts.contactsRuntime
  local compactMode, dock = parts.compactMode, parts.dock
  local windowVisibility = parts.panelWiring.windowVisibility
  local composer = composerRuntime.composer
  local isComposerFocusHeld = composerRuntime.isComposerFocusHeld
  return LifecycleWiring.Setup({
    layout = shell.layout,
    setContactsWidth = function(nextContactsWidth)
      currentContactsWidth = nextContactsWidth or currentContactsWidth
      windowGeometry.setContactsWidth(currentContactsWidth)
    end,
    composer = composer,
    bindComposerHeight = composerRuntime.bindHeightChanged,
    contactsController = contactsRuntime.contactsController,
    conversation = parts.conversation,
    refreshContacts = contactsRuntime.refreshContacts,
    getSelectedConversationKey = parts.getSelectedConversationKey,
    onContactsWidth = parts.panelWiring.onContactsWidth,
    getCurrentContacts = contactsRuntime.getCurrentContacts,
    selectedContact = options.selectedContact,
    initialConversation = options.conversation,
    initialStatus = options.status,
    refreshSelection = composerRuntime.refreshSelection,
    setOptionsVisible = windowVisibility.setOptionsVisible,
    chrome = shell.chrome,
    settingsPanels = shell.settingsRuntime.settingsPanels,
    closeWindow = windowVisibility.closeWindow,
    onResetWindowPosition = parts.onResetWindowPosition,
    onWindowMoved = function()
      dock.onWindowMoved()
    end,
    onResetIconPosition = options.onResetIconPosition,
    onClearAllChats = options.onClearAllChats,
    onStartConversation = options.onStartConversation,
    isShown = isShown,
    windowGeometry = windowGeometry,
    frame = shell.frame,
    refreshWindowAlpha = composerRuntime.windowAlpha.refreshWindowAlpha,
    onPositionChanged = parts.onPositionChanged,
    onBack = function()
      return compactMode.onBack()
    end,
    theme = Theme,
    composerInput = composer.input,
    getAutoFocusChatInput = function()
      return not isComposerFocusHeld() and settingsConfig.autoFocusComposer == true and not compactMode.isListView()
    end,
    getEscapeClosesWindow = function()
      return settingsConfig.escapeClosesWindow ~= false
    end,
    onStrataChanged = function(strata)
      dock.onStrataChanged(strata)
    end,
    isWindowPart = function(candidate)
      return dock.isWindowPart(candidate)
    end,
    isPinned = function()
      return parts.edge.side() ~= nil
    end,
    isContactsCollapsed = windowGeometry.isCollapsed,
    setContactsCollapsed = function(collapsed, pointerWidth)
      parts.getContactsRail().snap(collapsed, pointerWidth)
    end,
    onStateApplied = function(appliedState)
      parts.getContactsRail().setCollapsed(appliedState.contactsCollapsed == true)
    end,
  })
end

ns.MessengerWindowLifecycleSetup = LifecycleSetup

return LifecycleSetup
