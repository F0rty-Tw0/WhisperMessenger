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

  local tabSelections = { whispers = nil, groups = nil, requests = nil }

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

  local function restoreSelection(newMode)
    local nextKey = tabSelections[newMode]
    if not nextKey then
      refreshSelection({})
      return
    end

    for _, item in ipairs(getCurrentContacts() or {}) do
      if item ~= nil and item.conversationKey == nextKey then
        handleContactSelected(item)
        return
      end
    end

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
