local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsRuntime = ns.MessengerWindowContactsRuntime or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRuntime")
local TabSelectionMemory = ns.MessengerWindowTabSelectionMemory or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.TabSelectionMemory")
local ContactsRail = ns.MessengerWindowContactsRail or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsRail")
local MarkAllReadButton = ns.MessengerWindowChromeBuilderMarkAllReadButton
  or require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder.MarkAllReadButton")

local ContactsWiring = {}

-- Builds the contacts runtime (rows, paging, scroll hooks) with its per-tab
-- selection memory, and binds the search input scripts.
-- The conversation pane and selection controller are built after the
-- contacts, so the callbacks reach them through getters at call time.
-- options: layout, frame, chrome, settingsConfig, windowGeometry,
-- windowOptions (MessengerWindow.Create options), getSelectionController,
-- getConversation, getSelectedConversationKey
function ContactsWiring.Create(factory, options)
  local layout = options.layout
  local chrome = options.chrome
  local windowOptions = options.windowOptions or {}
  local getSelectionController = options.getSelectionController
  local getConversation = options.getConversation

  -- Declared before Create so getCurrentContacts captures THIS local; Lua
  -- local scope begins after the declaration statement completes.
  local contactsRuntime
  local tabSelectionMemory = TabSelectionMemory.Create({
    getSelectedConversationKey = options.getSelectedConversationKey,
    getCurrentContacts = function()
      if contactsRuntime and contactsRuntime.getCurrentContacts then
        return contactsRuntime.getCurrentContacts() or {}
      end
      return {}
    end,
    handleContactSelected = function(item)
      local selectionController = getSelectionController()
      if selectionController then
        selectionController.handleContactSelected(item)
      end
    end,
    refreshSelection = function(nextState)
      local selectionController = getSelectionController()
      if selectionController then
        selectionController.refresh(nextState)
      end
    end,
  })
  contactsRuntime = ContactsRuntime.Create(factory, {
    contactsPane = layout.contactsPane,
    windowFrame = options.frame,
    nativeChrome = layout.nativeChrome == true,
    contactsView = layout.contactsView,
    initialContacts = windowOptions.contacts or {},
    settingsConfig = options.settingsConfig,
    isCompact = options.windowGeometry.isCollapsed,
    initialTabMode = windowOptions.initialTabMode,
    onTabModeChanged = function(mode)
      local conversation = getConversation()
      if conversation and conversation.headerEmpty then
        conversation.headerEmpty.setMode(mode)
      end
      if windowOptions.onTabModeChanged then
        windowOptions.onTabModeChanged(mode)
      end
    end,
    onTabModeSwapSelection = tabSelectionMemory.onTabModeSwapSelection,
    onSelect = tabSelectionMemory.onSelect,
    onContactClicked = windowOptions.onContactClicked,
    onPin = windowOptions.onPin,
    onRemove = windowOptions.onRemove,
    onMarkUnread = windowOptions.onMarkUnread,
    onUpdatePrefs = windowOptions.onUpdatePrefs,
    onIgnorePlayer = windowOptions.onIgnorePlayer,
    onUnblockPlayer = windowOptions.onUnblockPlayer,
    isPlayerBlocked = windowOptions.isPlayerBlocked,
    whoPlayer = windowOptions.whoPlayer,
    onReorder = windowOptions.onReorder,
    onAllContactsRefreshed = function(allContacts)
      chrome.setMarkAllReadShown(MarkAllReadButton.HasUnread(allContacts))
    end,
    onSearchAvailableChanged = function(available)
      ContactsRail.SetSearchAvailable(layout, available)
    end,
    contactsSearchInput = layout.contactsSearchInput,
    contactsSearchClearButton = layout.contactsSearchClearButton,
    contactsSearchPlaceholder = layout.contactsSearchPlaceholder,
    getSelectedConversationKey = options.getSelectedConversationKey,
  })
  contactsRuntime.bindInputScripts()
  return contactsRuntime
end

ns.MessengerWindowContactsWiring = ContactsWiring

return ContactsWiring
