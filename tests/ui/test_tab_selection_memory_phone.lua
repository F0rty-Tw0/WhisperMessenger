local TabSelectionMemory = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.TabSelectionMemory")

return function()
  -- test_tab_switch_on_the_phone_list_never_reopens_a_chat
  do
    local selected, cleared = 0, 0
    local item = { conversationKey = "a", channel = "WOW" }
    local memory = TabSelectionMemory.Create({
      rememberSelections = false,
      getCurrentContacts = function()
        return { item }
      end,
      handleContactSelected = function()
        selected = selected + 1
      end,
      refreshSelection = function()
        cleared = cleared + 1
      end,
    })
    memory.onSelect(item)
    selected = 0
    memory.onTabModeSwapSelection("groups", "whispers")
    assert(selected == 0, "the list stays the list")
    assert(cleared == 1, "the tab still refreshes")
  end

  -- test_phone_tab_switch_clears_through_clear_selection
  do
    local cleared, refreshed, selected = 0, 0, 0
    local open = { conversationKey = "a", channel = "WOW" }
    local memory = TabSelectionMemory.Create({
      rememberSelections = false,
      getSelectedConversationKey = function()
        return "a"
      end,
      getCurrentContacts = function()
        return { open }
      end,
      clearSelection = function()
        cleared = cleared + 1
      end,
      refreshSelection = function()
        refreshed = refreshed + 1
      end,
      handleContactSelected = function()
        selected = selected + 1
      end,
    })
    memory.onTabModeSwapSelection("whispers", "groups")
    assert(cleared == 1 and refreshed == 0 and selected == 0, "cleared " .. cleared .. " refreshed " .. refreshed)
  end

  -- test_phone_tab_switch_with_no_chat_open_only_refreshes
  do
    local cleared, refreshed = 0, 0
    local memory = TabSelectionMemory.Create({
      rememberSelections = false,
      clearSelection = function()
        cleared = cleared + 1
      end,
      refreshSelection = function()
        refreshed = refreshed + 1
      end,
    })
    memory.onTabModeSwapSelection("groups", "whispers")
    assert(cleared == 0 and refreshed == 1, "cleared " .. cleared .. " refreshed " .. refreshed)
  end

  -- test_phone_tab_switch_to_the_open_chats_own_tab_keeps_the_selection
  do
    local cleared, refreshed = 0, 0
    local open = { conversationKey = "a", channel = "WOW" }
    local memory = TabSelectionMemory.Create({
      rememberSelections = false,
      getSelectedConversationKey = function()
        return "a"
      end,
      getCurrentContacts = function()
        return { open }
      end,
      clearSelection = function()
        cleared = cleared + 1
      end,
      refreshSelection = function()
        refreshed = refreshed + 1
      end,
    })
    memory.onTabModeSwapSelection("groups", "whispers")
    assert(cleared == 0 and refreshed == 1, "cleared " .. cleared .. " refreshed " .. refreshed)
  end

  -- test_phone_tab_switch_clears_a_selected_chat_missing_from_the_contacts
  do
    local cleared, refreshed = 0, 0
    local memory = TabSelectionMemory.Create({
      rememberSelections = false,
      getSelectedConversationKey = function()
        return "gone"
      end,
      getCurrentContacts = function()
        return { { conversationKey = "a", channel = "WOW" } }
      end,
      clearSelection = function()
        cleared = cleared + 1
      end,
      refreshSelection = function()
        refreshed = refreshed + 1
      end,
    })
    memory.onTabModeSwapSelection("whispers", "groups")
    assert(cleared == 1 and refreshed == 0, "cleared " .. cleared .. " refreshed " .. refreshed)
  end

  -- test_classic_tab_switch_with_nothing_remembered_ignores_clear_selection
  do
    local cleared, refreshed = 0, 0
    local memory = TabSelectionMemory.Create({
      rememberSelections = true,
      clearSelection = function()
        cleared = cleared + 1
      end,
      refreshSelection = function()
        refreshed = refreshed + 1
      end,
    })
    memory.onTabModeSwapSelection("groups", "whispers")
    assert(cleared == 0 and refreshed == 1, "cleared " .. cleared .. " refreshed " .. refreshed)
  end
end
