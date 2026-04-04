local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactSearch = ns.MessengerWindowContactSearch
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactSearch")

local ContactsSearchController = {}

function ContactsSearchController.Create(options)
  local contacts = options.contacts
  local contactsController = options.contactsController
  local contactSearch = options.contactSearch or ContactSearch
  local contactsSearchInput = options.contactsSearchInput
  local contactsSearchClearButton = options.contactsSearchClearButton
  local contactsSearchPlaceholder = options.contactsSearchPlaceholder
  local getSelectedConversationKey = options.getSelectedConversationKey or function()
    return nil
  end

  local currentContacts = options.initialContacts or {}
  local contactsSearchQuery = ""

  local function syncSearchInputVisual()
    local hasSearch = contactsSearchQuery ~= ""
    if contactsSearchPlaceholder and contactsSearchPlaceholder.SetShown then
      contactsSearchPlaceholder:SetShown(not hasSearch)
    end
    if contactsSearchClearButton and contactsSearchClearButton.SetShown then
      contactsSearchClearButton:SetShown(hasSearch)
    end
  end

  local function refresh(nextContacts, selectedConversationKey, resetPaging)
    if nextContacts ~= nil then
      currentContacts = nextContacts
    end

    local visibleContacts = contactSearch.BuildVisibleContacts(currentContacts, contactsSearchQuery)
    local selectedKey = selectedConversationKey
    if selectedKey ~= nil and not contactSearch.IsConversationVisible(visibleContacts, selectedKey) then
      selectedKey = nil
    end

    contactsController.rows = contactsController.refresh(visibleContacts, selectedKey, resetPaging)
    contacts.rows = contactsController.rows
    syncSearchInputVisual()
    return contacts.rows
  end

  local function bindInputScripts()
    if contactsSearchInput and contactsSearchInput.SetScript then
      contactsSearchInput:SetScript("OnTextChanged", function()
        local searchText = contactsSearchInput.GetText and contactsSearchInput:GetText()
          or contactsSearchInput.text
          or ""
        contactsSearchQuery = contactSearch.NormalizeSearchQuery(searchText)
        refresh(nil, getSelectedConversationKey(), true)
      end)
      contactsSearchInput:SetScript("OnEscapePressed", function()
        if contactsSearchInput.SetText then
          contactsSearchInput:SetText("")
        else
          contactsSearchInput.text = ""
        end
        contactsSearchQuery = ""
        refresh(nil, getSelectedConversationKey(), true)
        if contactsSearchInput.ClearFocus then
          contactsSearchInput:ClearFocus()
        end
      end)
    end

    if contactsSearchClearButton and contactsSearchClearButton.SetScript then
      contactsSearchClearButton:SetScript("OnClick", function()
        if contactsSearchInput and contactsSearchInput.SetText then
          contactsSearchInput:SetText("")
        elseif contactsSearchInput then
          contactsSearchInput.text = ""
        end
        contactsSearchQuery = ""
        refresh(nil, getSelectedConversationKey(), true)
      end)
    end

    syncSearchInputVisual()
  end

  return {
    refresh = refresh,
    bindInputScripts = bindInputScripts,
    getCurrentContacts = function()
      return currentContacts
    end,
  }
end

ns.MessengerWindowContactsSearchController = ContactsSearchController

return ContactsSearchController
