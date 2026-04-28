local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SelectionController = {}

function SelectionController.Create(options)
  local refreshContacts = options.refreshContacts
  local refreshConversationPane = options.refreshConversationPane
  local syncComposerSelectedContact = options.syncComposerSelectedContact
  local setComposerEnabled = options.setComposerEnabled

  local currentSelectedContact = nil
  local currentConversation = nil
  local currentStatus = nil
  local currentNotice = nil

  local function refresh(nextState, resetPaging)
    nextState = nextState or {}
    currentSelectedContact = nextState.selectedContact
    currentConversation = nextState.conversation
    currentStatus = nextState.status
    currentNotice = nextState.notice

    refreshContacts(nextState.contacts, currentSelectedContact and currentSelectedContact.conversationKey or nil, resetPaging)
    refreshConversationPane(currentSelectedContact, currentConversation, currentStatus, currentNotice)
    syncComposerSelectedContact(currentSelectedContact)
    setComposerEnabled(currentSelectedContact, currentNotice, currentStatus)
  end

  local function buildSelectedState(item)
    local nextState = nil
    if options.onSelectConversation then
      nextState = options.onSelectConversation(item.conversationKey, item)
    end

    if nextState == nil then
      nextState = {
        selectedContact = options.getSelectedContact and options.getSelectedContact(item.conversationKey, item) or item,
        conversation = options.getConversation and options.getConversation(item.conversationKey, item) or nil,
        status = options.getStatus and options.getStatus(item.conversationKey, item) or nil,
      }
    elseif nextState.selectedContact == nil then
      nextState.selectedContact = item
    end

    return nextState
  end

  local function handleContactSelected(item)
    refresh(buildSelectedState(item))
  end

  return {
    refresh = refresh,
    handleContactSelected = handleContactSelected,
    getSelectedConversationKey = function()
      return currentSelectedContact and currentSelectedContact.conversationKey or nil
    end,
  }
end

ns.MessengerWindowSelectionController = SelectionController

return SelectionController
