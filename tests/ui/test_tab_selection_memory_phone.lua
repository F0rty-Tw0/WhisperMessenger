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
end
