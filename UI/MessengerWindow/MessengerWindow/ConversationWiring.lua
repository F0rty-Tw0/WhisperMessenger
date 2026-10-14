local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local MessageActions = ns.MessengerWindowMessageActions or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.MessageActions")

local ConversationWiring = {}

-- Builds the conversation pane with the window's message callbacks and
-- titles its empty state for the current contacts tab.
-- options: threadPane, windowOptions (MessengerWindow.Create options),
-- nativeChrome, tabMode
-- Returns { conversation, messageActions }; bind messageActions to the
-- composer once it exists.
function ConversationWiring.Create(factory, options)
  local windowOptions = options.windowOptions or {}
  local nativeChrome = options.nativeChrome
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
    hideEmptyHeader = nativeChrome,
    nativeChrome = nativeChrome,
  })
  conversation.headerEmpty.setMode(options.tabMode)
  return { conversation = conversation, messageActions = messageActions }
end

ns.MessengerWindowConversationWiring = ConversationWiring

return ConversationWiring
