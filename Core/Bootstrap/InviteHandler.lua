local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SendHandler = ns.BootstrapSendHandler or require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local InviteHandler = {}

-- One whisper, sent at most once per conversation. Kept short enough that the
-- translated copy still fits WoW's 255-byte chat limit.
InviteHandler.INVITE_TEXT =
  "Hey! I use WhisperMessenger for whispers: messenger window, history, unread badges, reactions, typing/seen. Free on CurseForge and Wago, grab it and we get all of it between us."

function InviteHandler.HandleInvite(runtime, selectedContact, refreshWindow)
  if type(runtime) ~= "table" or type(selectedContact) ~= "table" then
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
  local accepted = SendHandler.HandleSend(runtime, {
    conversationKey = selectedContact.conversationKey,
    target = selectedContact.displayName,
    displayName = selectedContact.displayName,
    battleTag = selectedContact.battleTag,
    channel = selectedContact.channel,
    bnetAccountID = selectedContact.bnetAccountID,
    conversationID = selectedContact.conversationID,
    guid = selectedContact.guid,
    gameAccountName = selectedContact.gameAccountName,
    text = Localization.Text(InviteHandler.INVITE_TEXT),
  }, refresh)

  if accepted then
    conversation.inviteSent = true
    refresh()
  end
  return accepted
end

ns.BootstrapInviteHandler = InviteHandler
return InviteHandler
