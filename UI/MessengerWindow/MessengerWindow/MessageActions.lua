local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationPane = ns.ConversationPane or require("WhisperMessenger.UI.ConversationPane")
local MessageReplies = ns.MessageReplies or require("WhisperMessenger.Model.MessageReplies")

-- Glue between bubbles, the composer and the window callback: Reply only
-- touches the composer; every other action (Send now, Retry, Discard) goes
-- to the callback.
local MessageActions = {}

function MessageActions.Create(onMessageAction)
  local pane
  local composer
  local actions = {}

  function actions.bind(nextPane, nextComposer)
    pane = nextPane
    composer = nextComposer
  end

  function actions.onMessageAction(selectedContact, message, action)
    if action == "reply" then
      if composer and type(selectedContact) == "table" then
        composer.setReply(selectedContact.conversationKey, MessageReplies.BuildTarget(message))
      end
      return true
    end
    if type(onMessageAction) ~= "function" then
      return false
    end
    return onMessageAction(selectedContact, message, action)
  end

  function actions.onReplyChanged(replyTo)
    if pane then
      ConversationPane.SetReply(pane, replyTo, composer and composer.clearReply)
    end
  end

  return actions
end

ns.MessengerWindowMessageActions = MessageActions
return MessageActions
