local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsController = ns.MessengerWindowContactsController
  or require("WhisperMessenger.UI.MessengerWindow.ContactsController")
local ContactsSearchController = ns.MessengerWindowContactsSearchController
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsSearchController")
local ContactSearch = ns.MessengerWindowContactSearch
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactSearch")

local ContactsRuntime = {}

function ContactsRuntime.Create(factory, options)
  options = options or {}

  local contactsController = ContactsController.Create(factory, options.contactsView, options.initialContacts or {}, {
    getHideMessagePreview = function()
      return options.settingsConfig and options.settingsConfig.hideMessagePreview == true
    end,
    onSelect = function(item)
      if options.onSelect then
        options.onSelect(item)
      end
    end,
    onPin = function(item)
      if options.onPin then
        options.onPin(item)
      end
    end,
    onRemove = function(item)
      if options.onRemove then
        options.onRemove(item)
      end
    end,
    onReorder = function(orders)
      if options.onReorder then
        options.onReorder(orders)
      end
    end,
  })

  local contacts = {
    rows = contactsController.rows,
    scrollFrame = contactsController.scrollFrame,
    scrollBar = contactsController.scrollBar,
    content = contactsController.content,
    view = contactsController.view,
  }

  local contactsSearchController = ContactsSearchController.Create({
    contacts = contacts,
    contactsController = contactsController,
    contactSearch = options.contactSearch or ContactSearch,
    initialContacts = options.initialContacts or {},
    contactsSearchInput = options.contactsSearchInput,
    contactsSearchClearButton = options.contactsSearchClearButton,
    contactsSearchPlaceholder = options.contactsSearchPlaceholder,
    getSelectedConversationKey = options.getSelectedConversationKey,
  })

  return {
    contactsController = contactsController,
    contacts = contacts,
    refreshContacts = function(nextContacts, selectedConversationKey, resetPaging)
      return contactsSearchController.refresh(nextContacts, selectedConversationKey, resetPaging)
    end,
    getCurrentContacts = function()
      return contactsSearchController.getCurrentContacts()
    end,
    bindInputScripts = function()
      contactsSearchController.bindInputScripts()
    end,
  }
end

ns.MessengerWindowContactsRuntime = ContactsRuntime

return ContactsRuntime
