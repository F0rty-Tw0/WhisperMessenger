local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local Composer = ns.Composer or require("WhisperMessenger.UI.Composer")
local AlphaController = ns.MessengerWindowAlphaController or require("WhisperMessenger.UI.MessengerWindow.AlphaController")
local SelectionSync = ns.MessengerWindowSelectionSync or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionSync")
local SelectionController = ns.MessengerWindowSelectionController
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SelectionController")
local WindowAlpha = ns.MessengerWindowWindowAlpha or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowAlpha")

local ComposerRuntime = {}

-- The composer plus what follows it: the window alpha tied to its input,
-- the selection that feeds it, and the held-back focus on a quiet show.
function ComposerRuntime.Create(factory, options)
  local frame = options.frame
  local layout = options.layout
  local settingsConfig = options.settingsConfig
  local windowOptions = options.windowOptions
  local conversation = options.conversation
  local messageActions = options.messageActions
  local composerSelectedContact = {}

  local composerOptions = {
    nativeChrome = layout.nativeChrome == true,
    onDraftChanged = windowOptions.onDraftChanged,
    onReplyChanged = messageActions.onReplyChanged,
    getQuickReplies = function()
      return settingsConfig.quickReplies
    end,
    getDeselectOnSend = function()
      return settingsConfig.deselectComposerOnSend == true
    end,
  }
  local composer = Composer.Create(factory, layout.composerPane, composerSelectedContact, windowOptions.onSend or function(...)
    local _ = ...
  end, options.closeWindow, function()
    return settingsConfig.doubleEscapeToClose == true or settingsConfig.escapeClosesWindow == false
  end, windowOptions.onTyping, composerOptions)
  options.settingsRuntime.setThemeTargets(conversation, composer)
  messageActions.bind(conversation, composer)

  -- Alpha helpers (capture composer.input now that composer exists)
  local windowAlpha = WindowAlpha.Create({
    alphaController = AlphaController,
    frame = frame,
    composerInput = composer.input,
    settingsConfig = settingsConfig,
  })

  -- Selection management
  local selectionController = SelectionController.Create({
    refreshContacts = options.refreshContacts,
    refreshConversationPane = function(selectedContact, selectedConversation, selectedStatus, noticeText)
      ConversationPane.Refresh(conversation, selectedContact, selectedConversation, selectedStatus, noticeText)
    end,
    syncComposerSelectedContact = function(selectedContact)
      SelectionSync.SyncComposerSelectedContact(composerSelectedContact, selectedContact, composer, windowOptions.getDraft)
    end,
    setComposerEnabled = function(selectedContact, noticeText)
      SelectionSync.SetComposerEnabled(composer, selectedContact, noticeText)
    end,
    onSelectConversation = windowOptions.onSelectConversation,
    onSelectionChanged = options.onSelectionChanged,
    getSelectedContact = windowOptions.getSelectedContact,
    getConversation = windowOptions.getConversation,
    getStatus = windowOptions.getStatus,
  })

  local function refreshSelection(nextState, resetPaging)
    selectionController.refresh(nextState, resetPaging)
  end

  -- OnShow focuses the composer when the setting is on; an open the player
  -- did not ask for (combat end) shows the window with that focus held back.
  local holdComposerFocus = false
  local function showWithoutComposerFocus()
    holdComposerFocus = true
    local ok, err = pcall(frame.Show, frame)
    holdComposerFocus = false
    if not ok then
      error(err, 0)
    end
  end

  local function isComposerFocusHeld()
    return holdComposerFocus
  end

  return {
    composer = composer,
    windowAlpha = windowAlpha,
    selectionController = selectionController,
    refreshSelection = refreshSelection,
    showWithoutComposerFocus = showWithoutComposerFocus,
    isComposerFocusHeld = isComposerFocusHeld,
  }
end

ns.MessengerWindowComposerRuntime = ComposerRuntime

return ComposerRuntime
