local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SelectionSync = {}

function SelectionSync.SyncComposerSelectedContact(target, selectedContact)
  target.conversationKey = selectedContact and selectedContact.conversationKey or nil
  target.displayName = selectedContact and selectedContact.displayName or nil
  target.channel = selectedContact and selectedContact.channel or nil
  target.bnetAccountID = selectedContact and selectedContact.bnetAccountID or nil
  target.conversationID = selectedContact and selectedContact.conversationID or nil
  target.guid = selectedContact and selectedContact.guid or nil
  target.gameAccountName = selectedContact and selectedContact.gameAccountName or nil
end

function SelectionSync.SetComposerEnabled(composer, selectedContact, noticeText, status)
  local hasNotice = noticeText and noticeText ~= ""
  local isIgnored = status and status.status == "Ignored"
  local enabled = selectedContact ~= nil and not hasNotice and not isIgnored
  if composer.setEnabled then
    composer.setEnabled(enabled)
  end
end

ns.MessengerWindowSelectionSync = SelectionSync

return SelectionSync
