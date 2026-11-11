local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local MessageActions = ns.MessengerWindowMessageActions or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.MessageActions")
local StartConversationDialog = ns.MessengerWindowWindowScriptsButtonsStartConversationDialog
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.StartConversationDialog")

local ConversationWiring = {}

-- Builds the conversation pane with the window's message callbacks and
-- titles its empty state for the current contacts tab.
-- options: threadPane, windowOptions (MessengerWindow.Create options),
-- nativeChrome, tabMode, settingsConfig
-- Returns { conversation, messageActions }; bind messageActions to the
-- composer once it exists.
function ConversationWiring.Create(factory, options)
  local windowOptions = options.windowOptions or {}
  local nativeChrome = options.nativeChrome
  local settingsConfig = options.settingsConfig or {}
  local messageActions = MessageActions.Create(windowOptions.onMessageAction)
  local conversation = ConversationPane.Create(factory, options.threadPane, windowOptions.selectedContact, windowOptions.conversation, {
    onMessageAction = messageActions.onMessageAction,
    onReact = windowOptions.onReact,
    canReact = windowOptions.canReact,
    onInviteContact = windowOptions.onInviteContact,
    canInviteContact = windowOptions.canInviteContact,
    onAcceptRequest = windowOptions.onAcceptRequest,
    onDeleteRequest = windowOptions.onDeleteRequest,
    onMarkUnread = windowOptions.onMarkUnread,
    onUpdatePrefs = windowOptions.onUpdatePrefs,
    onIgnorePlayer = windowOptions.onIgnorePlayer,
    isPlayerBlocked = windowOptions.isPlayerBlocked,
    onUnblockPlayer = windowOptions.onUnblockPlayer,
    whoPlayer = windowOptions.whoPlayer,
    onHeaderClicked = windowOptions.onHeaderClicked,
    getContactInfoLines = windowOptions.getContactInfoLines,
    hideEmptyHeader = nativeChrome,
    nativeChrome = nativeChrome,
    onStartNewWhisper = StartConversationDialog.Open,
    -- Read live on every render, the first one included.
    isChannelContextShown = function()
      return settingsConfig.showChannelContext ~= false
    end,
  })
  conversation.headerEmpty.setMode(options.tabMode)
  return { conversation = conversation, messageActions = messageActions }
end

ns.MessengerWindowConversationWiring = ConversationWiring

return ConversationWiring
