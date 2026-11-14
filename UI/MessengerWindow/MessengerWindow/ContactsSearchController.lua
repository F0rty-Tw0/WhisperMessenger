local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactSearch = ns.MessengerWindowContactSearch or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactSearch")

local ContactsSearchController = {}

-- Typing waits this long before filtering, so a fast typist pays for one
-- history scan instead of one per keystroke.
local SEARCH_DEBOUNCE_SECONDS = 0.15

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
  local pendingRefreshTimer = nil

  local function syncSearchInputVisual()
    local hasSearch = contactsSearchQuery ~= ""
    if contactsSearchPlaceholder and contactsSearchPlaceholder.SetShown then
      contactsSearchPlaceholder:SetShown(not hasSearch)
    end
    if contactsSearchClearButton and contactsSearchClearButton.SetShown then
      contactsSearchClearButton:SetShown(hasSearch)
    end
  end

  local getTabFilter = options.getTabFilter
  local onAfterFilter = options.onAfterFilter

  local function cancelPendingRefresh()
    if pendingRefreshTimer ~= nil then
      pendingRefreshTimer:Cancel()
      pendingRefreshTimer = nil
    end
  end

  local function refresh(nextContacts, selectedConversationKey, resetPaging)
    -- A pending search pass would have reset paging; whoever applies the new
    -- query in its place must do the same.
    resetPaging = resetPaging or pendingRefreshTimer ~= nil
    cancelPendingRefresh()
    if nextContacts ~= nil then
      currentContacts = nextContacts
    end

    local visibleContacts = contactSearch.BuildVisibleContacts(currentContacts, contactsSearchQuery)

    -- Apply tab filter (Whispers / Groups) when provided
    if type(getTabFilter) == "function" then
      visibleContacts = getTabFilter(visibleContacts)
    end

    -- Notify caller after filtering so it can show/hide empty-state UI and
    -- compute per-tab unread counts from the unfiltered list.
    if type(onAfterFilter) == "function" then
      onAfterFilter(visibleContacts, currentContacts)
    end

    local selectedKey = selectedConversationKey
    if selectedKey ~= nil and not contactSearch.IsConversationVisible(visibleContacts, selectedKey) then
      selectedKey = nil
    end

    contactsController.rows = contactsController.refresh(visibleContacts, selectedKey, resetPaging)
    contacts.rows = contactsController.rows
    syncSearchInputVisual()
    return contacts.rows
  end

  local function scheduleSearchRefresh()
    cancelPendingRefresh()
    local timer = _G.C_Timer
    if type(timer) ~= "table" or type(timer.NewTimer) ~= "function" then
      refresh(nil, getSelectedConversationKey(), true)
      return
    end
    local scheduled
    scheduled = timer.NewTimer(SEARCH_DEBOUNCE_SECONDS, function()
      if pendingRefreshTimer ~= scheduled then
        return
      end
      pendingRefreshTimer = nil
      refresh(nil, getSelectedConversationKey(), true)
    end)
    pendingRefreshTimer = scheduled
  end

  local function bindInputScripts()
    if contactsSearchInput and contactsSearchInput.SetScript then
      contactsSearchInput:SetScript("OnTextChanged", function()
        local searchText = contactsSearchInput.GetText and contactsSearchInput:GetText() or contactsSearchInput.text or ""
        contactsSearchQuery = contactSearch.NormalizeSearchQuery(searchText)
        if contactsSearchQuery == "" then
          refresh(nil, getSelectedConversationKey(), true)
          return
        end
        syncSearchInputVisual()
        scheduleSearchRefresh()
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
