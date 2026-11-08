local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactsTabFilter = ns.ContactsTabFilter or require("WhisperMessenger.UI.ContactsList.ContactsTabFilter")

local TabSelectionMemory = {}

function TabSelectionMemory.Create(options)
  options = options or {}

  local contactsTabFilter = options.contactsTabFilter or ContactsTabFilter
  local getSelectedConversationKey = options.getSelectedConversationKey or function()
    return nil
  end
  local getCurrentContacts = options.getCurrentContacts or function()
    return {}
  end
  local handleContactSelected = options.handleContactSelected or function() end
  local refreshSelection = options.refreshSelection or function() end
  local clearSelection = options.clearSelection or function()
    refreshSelection({})
  end

  -- Compact layout: a tab shows its list, never a chat it last had open;
  -- clearSelection drops the runtime's selection too (default: empty pane).
  local rememberSelections = options.rememberSelections ~= false

  local tabSelections = { whispers = nil, groups = nil, channels = nil, requests = nil }

  local function saveLiveSelection(oldMode)
    local liveKey = getSelectedConversationKey()
    if liveKey == nil then
      return
    end

    for _, item in ipairs(getCurrentContacts() or {}) do
      if item ~= nil and item.conversationKey == liveKey then
        if contactsTabFilter.ModeOf(item) == oldMode then
          tabSelections[oldMode] = liveKey
        end
        return
      end
    end
  end

  -- True when a chat is open that belongs to another tab than newMode. A
  -- chat already in newMode (a request that moved to Whispers) keeps its
  -- runtime selection; the pane's own UI selection is still reset.
  local function liveChatIsElsewhere(newMode)
    local liveKey = getSelectedConversationKey()
    if liveKey == nil then
      return false
    end
    for _, item in ipairs(getCurrentContacts() or {}) do
      if item ~= nil and item.conversationKey == liveKey then
        return contactsTabFilter.ModeOf(item) ~= newMode
      end
    end
    return true
  end

  local function restoreSelection(newMode)
    if not rememberSelections then
      if liveChatIsElsewhere(newMode) then
        clearSelection()
      else
        refreshSelection({})
      end
      return
    end

    local nextKey = tabSelections[newMode]
    if not nextKey then
      refreshSelection({})
      return
    end

    -- A remembered chat that moved tabs (an accepted request now lives on
    -- Whispers) is forgotten here, so the tab shows its empty state.
    for _, item in ipairs(getCurrentContacts() or {}) do
      if item ~= nil and item.conversationKey == nextKey and contactsTabFilter.ModeOf(item) == newMode then
        handleContactSelected(item)
        return
      end
    end

    tabSelections[newMode] = nil
    refreshSelection({})
  end

  return {
    onTabModeSwapSelection = function(oldMode, newMode)
      saveLiveSelection(oldMode)
      restoreSelection(newMode)
    end,
    onSelect = function(item)
      if item and item.conversationKey then
        tabSelections[contactsTabFilter.ModeOf(item)] = item.conversationKey
      end
      handleContactSelected(item)
    end,
  }
end

ns.MessengerWindowTabSelectionMemory = TabSelectionMemory

return TabSelectionMemory
