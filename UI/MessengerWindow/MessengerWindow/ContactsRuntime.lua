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
local TabToggle = ns.ContactsListTabToggle or require("WhisperMessenger.UI.ContactsList.TabToggle")
local ContactsTabFilter = ns.ContactsTabFilter or require("WhisperMessenger.UI.ContactsList.ContactsTabFilter")
local EmptyState = ns.ContactsListEmptyState or require("WhisperMessenger.UI.ContactsList.EmptyState")
local BadgeFilter = ns.ToggleIconBadgeFilter or require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")

local ContactsRuntime = {}

function ContactsRuntime.Create(factory, options)
  options = options or {}

  -- Resolve settings config; showGroupChats defaults to true when absent
  local settingsConfig = options.settingsConfig or {}
  local function getShowGroupChats()
    return settingsConfig.showGroupChats ~= false
  end

  -- Tab toggle mode — persists in characterState via onTabModeChanged
  local currentTabMode = (options.initialTabMode and options.initialTabMode ~= "") and options.initialTabMode
    or "whispers"

  -- Forward-declare so the tab toggle callback can call it after
  -- contactsSearchController is wired below.
  local triggerTabRefresh = nil

  -- Build tab toggle UI (anchored to the contacts pane, not the scroll view)
  local tabToggle = nil
  if options.contactsPane then
    tabToggle = TabToggle.Create(factory, options.contactsPane, {
      initialMode = currentTabMode,
      onModeChanged = function(mode)
        if mode == currentTabMode then
          return
        end
        local oldMode = currentTabMode
        currentTabMode = mode
        if options.onTabModeChanged then
          options.onTabModeChanged(mode)
        end
        if triggerTabRefresh then
          triggerTabRefresh()
        end
        -- Fires after the list has re-filtered so `contacts.rows` already
        -- contains the new-mode rows when the caller swaps selection.
        if options.onTabModeSwapSelection then
          options.onTabModeSwapSelection(oldMode, mode)
        end
      end,
    })
    -- Show/hide based on feature flag
    tabToggle.setShown(getShowGroupChats())
  end

  local contactsController = ContactsController.Create(factory, options.contactsView, options.initialContacts or {}, {
    getHideMessagePreview = function()
      return settingsConfig.hideMessagePreview == true
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

  -- Empty-state hint shown when Groups tab is active but has no conversations.
  local emptyStateFrame = nil
  if options.contactsView then
    local contentParent = contactsController.content or options.contactsView
    emptyStateFrame = EmptyState.Create(contentParent)
  end

  local GROUPS_EMPTY_MSG = "No group chats yet.\nJoin a party or instance to see messages here."

  local contactsSearchController = ContactsSearchController.Create({
    contacts = contacts,
    contactsController = contactsController,
    contactSearch = options.contactSearch or ContactSearch,
    initialContacts = options.initialContacts or {},
    contactsSearchInput = options.contactsSearchInput,
    contactsSearchClearButton = options.contactsSearchClearButton,
    contactsSearchPlaceholder = options.contactsSearchPlaceholder,
    getSelectedConversationKey = options.getSelectedConversationKey,
    getTabFilter = function(items)
      return ContactsTabFilter.Apply(items, currentTabMode, getShowGroupChats())
    end,
    onAfterFilter = function(filtered, allContacts)
      -- Per-tab unread counters rendered as circular badges next to the labels.
      if tabToggle and tabToggle.setUnreadCounts then
        local source = allContacts or filtered
        tabToggle.setUnreadCounts(BadgeFilter.SumWhisperUnread(source), BadgeFilter.SumGroupUnread(source))
      end
      if emptyStateFrame == nil then
        return
      end
      if currentTabMode == "groups" and getShowGroupChats() and #filtered == 0 then
        EmptyState.Show(emptyStateFrame, GROUPS_EMPTY_MSG)
      else
        EmptyState.Hide(emptyStateFrame)
      end
    end,
  })

  -- Now that contactsSearchController exists, wire the forward declaration.
  triggerTabRefresh = function()
    contactsSearchController.refresh(nil, nil, true)
  end

  return {
    contactsController = contactsController,
    contacts = contacts,
    tabToggle = tabToggle,
    refreshContacts = function(nextContacts, selectedConversationKey, resetPaging)
      return contactsSearchController.refresh(nextContacts, selectedConversationKey, resetPaging)
    end,
    getCurrentContacts = function()
      return contactsSearchController.getCurrentContacts()
    end,
    bindInputScripts = function()
      contactsSearchController.bindInputScripts()
    end,
    refreshTabToggleVisibility = function()
      if tabToggle then
        tabToggle.setShown(getShowGroupChats())
      end
    end,
    setTabMode = function(mode)
      local resolved = mode or "whispers"
      if resolved == currentTabMode then
        return
      end
      local oldMode = currentTabMode
      currentTabMode = resolved
      if tabToggle then
        tabToggle.setMode(currentTabMode)
      end
      if options.onTabModeChanged then
        options.onTabModeChanged(currentTabMode)
      end
      if triggerTabRefresh then
        triggerTabRefresh()
      end
      if options.onTabModeSwapSelection then
        options.onTabModeSwapSelection(oldMode, currentTabMode)
      end
    end,
    getTabMode = function()
      return currentTabMode
    end,
  }
end

ns.MessengerWindowContactsRuntime = ContactsRuntime

return ContactsRuntime
