local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SendHandler = ns.BootstrapSendHandler or require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local ConversationSnapshot = ns.ConversationSnapshot or require("WhisperMessenger.Model.ConversationSnapshot")

local InviteHandler = {}

-- One whisper, sent at most once per conversation. Kept short enough that the
-- translated copy still fits WoW's 255-byte chat limit.
InviteHandler.INVITE_TEXT =
  "Hey! I use Whisper Messenger for whispers: messenger window, history, unread badges, reactions, typing/seen. Free on CurseForge and Wago, grab it and we get all of it between us."

-- "Show invite link" setting: on unless explicitly turned off.
function InviteHandler.IsEnabled(runtime)
  local settings = type(runtime) == "table" and runtime.accountState and runtime.accountState.settings
  return not settings or settings.showInviteLink ~= false
end

function InviteHandler.HandleInvite(runtime, selectedContact, refreshWindow)
  if type(runtime) ~= "table" or type(selectedContact) ~= "table" then
    return false
  end
  if not InviteHandler.IsEnabled(runtime) then
    return false
  end
  if selectedContact.channel ~= "WOW" and selectedContact.channel ~= "BN" then
    return false
  end

  local conversations = runtime.store and runtime.store.conversations
  local conversation = conversations and conversations[selectedContact.conversationKey]
  if conversation == nil or conversation.inviteSent == true then
    return false
  end

  local refresh = refreshWindow or function() end
  local payload = ConversationSnapshot.SendPayload(selectedContact, Localization.Text(InviteHandler.INVITE_TEXT))
  local accepted = SendHandler.HandleSend(runtime, payload, refresh)

  if accepted then
    conversation.inviteSent = true
    refresh()
  end
  return accepted
end

ns.BootstrapInviteHandler = InviteHandler
return InviteHandler
