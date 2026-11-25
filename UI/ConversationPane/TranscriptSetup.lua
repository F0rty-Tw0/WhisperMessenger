local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local Navigation = ns.ScrollViewNavigation or require("WhisperMessenger.UI.ScrollView.Navigation")
local TranscriptView = ns.ConversationPaneTranscriptView or require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local MessageReplies = ns.MessageReplies or require("WhisperMessenger.Model.MessageReplies")
local PlayerMenu = ns.ChatBubblePlayerMenu or require("WhisperMessenger.UI.ChatBubble.PlayerMenu")
local IgnorePrompt = ns.IgnorePrompt or require("WhisperMessenger.UI.Shared.IgnorePrompt")

local TranscriptSetup = {}

-- Bubble buttons and Reply report (open contact, message, action); a quote
-- click jumps to the original.
function TranscriptSetup.BindMessageActions(transcript, view, onMessageAction)
  transcript.onQuoteClick = function(replyTo)
    return TranscriptView.ScrollToReply(transcript, replyTo)
  end
  if type(onMessageAction) ~= "function" then
    return
  end
  transcript.onMessageAction = function(message, action)
    return onMessageAction(view._selectedContact, message, action)
  end
  transcript.canReply = function(message)
    return MessageReplies.CanReply(view._selectedContact and view._selectedContact.channel, message)
  end
  transcript.onReply = function(message)
    return onMessageAction(view._selectedContact, message, "reply")
  end
end

-- Whisper chats have one other player, ignored from the contact row menu.
-- Battle.net conversation senders are accounts, not characters.
local NON_PLAYER_SENDER_CHANNELS = { WOW = true, BN = true, BN_CONVERSATION = true }

-- A line from another player in a group or channel chat.
local function isOtherPlayerLine(contact, message)
  return contact ~= nil and not NON_PLAYER_SENDER_CHANNELS[contact.channel] and message.direction == "in"
end

local function canIgnoreSender(view, rowActions, message)
  return isOtherPlayerLine(view._selectedContact, message)
    and message.kind == "user"
    and type(message.playerName) == "string"
    and not string.find(message.playerName, "|K", 1, true)
    -- Blocking again would drop a timed block's end date.
    and not (type(rowActions.isPlayerBlocked) == "function" and rowActions.isPlayerBlocked(message.playerName) == true)
end

local function canWhoSender(view, rowActions, message)
  local name = message.playerName

  return type(rowActions.whoPlayer) == "function"
    and isOtherPlayerLine(view._selectedContact, message)
    and type(name) == "string"
    and name ~= ""
    and not string.find(name, "|K", 1, true)
end

-- rowActions: the window's row actions table, the one the contact rows use.
-- Sender name / portrait right-click: player menu for the selected contact,
-- built from that table. Bubble right-click in group and channel chats:
-- "Block sender…" for other players' lines
-- (rowActions.onIgnorePlayer(name, reason)). Shift + left-click on a
-- group/channel sender sends /who (rowActions.whoPlayer(name)).
function TranscriptSetup.BindPlayerMenu(transcript, view, rowActions)
  if type(rowActions.onIgnorePlayer) == "function" then
    transcript.canIgnoreSender = function(message)
      return canIgnoreSender(view, rowActions, message)
    end
    transcript.onIgnoreSender = function(message)
      IgnorePrompt.AskReason(function(reason)
        rowActions.onIgnorePlayer(message.playerName, reason)
      end)
    end
  end
  transcript.openPlayerMenu = function(message, anchor, button)
    if button == "LeftButton" and UIHelpers.isShiftDown() then
      if canWhoSender(view, rowActions, message) then
        rowActions.whoPlayer(message.playerName)
      end

      return false
    end

    return PlayerMenu.Open(message, anchor, nil, { contact = view._selectedContact, rowActions = rowActions })
  end
end

function TranscriptSetup.ConfigureTranscript(_factory, transcript, _parentWidth)
  ScrollView.RefreshMetrics(transcript, 0, false)

  local function refreshViewport()
    TranscriptView.RefreshViewport(transcript)
  end

  Navigation.InstallPostScrollHook(transcript, refreshViewport)
end

ns.ConversationPaneTranscriptSetup = TranscriptSetup

return TranscriptSetup
