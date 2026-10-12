local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Navigation = ns.ScrollViewNavigation or require("WhisperMessenger.UI.ScrollView.Navigation")
local TranscriptView = ns.ConversationPaneTranscriptView or require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hyperlinks = ns.UIHyperlinks or require("WhisperMessenger.UI.Hyperlinks")
local MessageReplies = ns.MessageReplies or require("WhisperMessenger.Model.MessageReplies")
local PlayerMenu = ns.ChatBubblePlayerMenu or require("WhisperMessenger.UI.ChatBubble.PlayerMenu")
local IgnorePrompt = ns.IgnorePrompt or require("WhisperMessenger.UI.Shared.IgnorePrompt")
local sizeValue = UIHelpers.sizeValue

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

local function canIgnoreSender(view, options, message)
  return isOtherPlayerLine(view._selectedContact, message)
    and message.kind == "user"
    and type(message.playerName) == "string"
    and not string.find(message.playerName, "|K", 1, true)
    -- Blocking again would drop a timed block's end date.
    and not (type(options.isPlayerBlocked) == "function" and options.isPlayerBlocked(message.playerName) == true)
end

local function canWhoSender(view, options, message)
  local name = message.playerName

  return type(options.whoPlayer) == "function"
    and isOtherPlayerLine(view._selectedContact, message)
    and type(name) == "string"
    and name ~= ""
    and not string.find(name, "|K", 1, true)
end

-- Sender name / portrait right-click: player menu for the selected contact,
-- with the same Mark unread / prefs callbacks the contact rows use. Bubble
-- right-click in group and channel chats: "Block sender…" for other
-- players' lines (options.onIgnorePlayer(name, reason)). Shift + left-click
-- on a group/channel sender sends /who (options.whoPlayer(name)).
function TranscriptSetup.BindPlayerMenu(transcript, view, options)
  if type(options.onIgnorePlayer) == "function" then
    transcript.canIgnoreSender = function(message)
      return canIgnoreSender(view, options, message)
    end
    transcript.onIgnoreSender = function(message)
      IgnorePrompt.AskReason(function(reason)
        options.onIgnorePlayer(message.playerName, reason)
      end)
    end
  end
  transcript.openPlayerMenu = function(message, anchor, button)
    if button == "LeftButton" and UIHelpers.isShiftDown() then
      if canWhoSender(view, options, message) then
        options.whoPlayer(message.playerName)
      end

      return false
    end

    return PlayerMenu.Open(message, anchor, nil, {
      contact = view._selectedContact,
      onMarkUnread = options.onMarkUnread,
      onUpdatePrefs = options.onUpdatePrefs,
      onIgnorePlayer = options.onIgnorePlayer,
      isPlayerBlocked = options.isPlayerBlocked,
      onUnblockPlayer = options.onUnblockPlayer,
    })
  end
end

function TranscriptSetup.ConfigureTranscript(factory, transcript, parentWidth)
  transcript.text = factory.CreateFrame("EditBox", nil, transcript.content)
  transcript.text:SetPoint("TOPLEFT", transcript.content, "TOPLEFT", 0, 0)
  if transcript.text.SetMultiLine then
    transcript.text:SetMultiLine(true)
  end
  if transcript.text.SetAutoFocus then
    transcript.text:SetAutoFocus(false)
  end
  if transcript.text.EnableMouse then
    transcript.text:EnableMouse(true)
  end
  if transcript.text.SetHyperlinksEnabled then
    transcript.text:SetHyperlinksEnabled(true)
  end
  if transcript.text.SetFontObject then
    transcript.text:SetFontObject(_G[Theme.FONTS.system_text] or Theme.FONTS.system_text)
  end
  if transcript.text.SetWidth then
    transcript.text:SetWidth(sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - 32))
  end
  if transcript.text.SetScript then
    transcript.text:SetScript("OnHyperlinkClick", function(self, link, text, button)
      Hyperlinks.HandleClick(link, text, button, self)
    end)
    transcript.text:SetScript("OnEditFocusGained", function(self)
      if self.ClearFocus then
        self:ClearFocus()
      end
    end)
  end
  transcript.text:SetText("")
  transcript.lines = {}

  TranscriptView._updateTranscriptLayout(transcript, false)

  local function refreshViewport()
    TranscriptView.RefreshViewport(transcript)
  end

  Navigation.InstallPostScrollHook(transcript, refreshViewport)
end

ns.ConversationPaneTranscriptSetup = TranscriptSetup

return TranscriptSetup
