local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")
local ToggleFlow = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ToggleFlow")
local TabSelectionMemory = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.TabSelectionMemory")

-- A message request belongs to the Requests tab: the other tabs never show
-- it in the pane, never jump to it, and remember their own selection.

local function coordinatorFor(tabMode, contacts, activeKey)
  local runtime = {
    availabilityByGUID = {},
    availabilityRequestedAt = {},
    now = function()
      return 1000
    end,
    chatApi = {},
    activeConversationKey = activeKey,
    store = { conversations = { [activeKey] = { channel = "WOW", request = true } } },
  }
  return WindowCoordinator.Create({
    runtime = runtime,
    buildContacts = function()
      return contacts
    end,
    getWindow = function()
      return {
        frame = {
          IsShown = function()
            return true
          end,
        },
        refreshSelection = function() end,
        getTabMode = function()
          return tabMode
        end,
      }
    end,
    getIcon = function()
      return {}
    end,
    buildMessagePreview = function()
      return nil
    end,
    isMythicRestricted = function()
      return false
    end,
    requestAvailability = function() end,
  })
end

return function()
  local requestItem = { conversationKey = "me::wow::stranger", channel = "WOW", isRequest = true }

  -- test_whispers_tab_drops_a_request_selection
  do
    local state = coordinatorFor("whispers", { requestItem }, "me::wow::stranger").refreshContacts()
    assert(state.selectedContact == nil, "a request never shows in the pane while on Whispers")
  end

  -- test_requests_tab_keeps_a_request_selection
  do
    local state = coordinatorFor("requests", { requestItem }, "me::wow::stranger").refreshContacts()
    assert(state.selectedContact and state.selectedContact.conversationKey == "me::wow::stranger", "the Requests tab shows its request")
  end

  -- test_toggle_does_not_jump_to_an_unread_request_from_whispers
  do
    local selected = {}
    local runtime = {
      accountState = { settings = { requestsInbox = true } },
      store = { conversations = { ["wow::stranger"] = { channel = "WOW", request = true } } },
    }
    local flow = ToggleFlow.Create({
      runtime = runtime,
      getWindow = function()
        return {
          getTabMode = function()
            return "whispers"
          end,
        }
      end,
      findLatestUnreadKey = function()
        return "wow::stranger"
      end,
      selectConversation = function(key)
        selected[#selected + 1] = key
      end,
    })
    assert(flow.conversationMatchesTab("wow::stranger", "whispers") == false, "request is not a Whispers conversation")
    assert(flow.conversationMatchesTab("wow::stranger", "requests") == true, "request is a Requests conversation")
    flow.toggle()
    assert(#selected == 0, "opening on Whispers does not jump to an unread request")
    runtime.accountState.settings.requestsInbox = false
    assert(flow.conversationMatchesTab("wow::stranger", "whispers") == true, "inbox off: it is a whisper again")
  end

  -- test_selection_memory_keeps_a_requests_slot
  do
    local liveKey
    local contacts = {
      { conversationKey = "a", channel = "WOW" },
      requestItem,
    }
    local memory = TabSelectionMemory.Create({
      getSelectedConversationKey = function()
        return liveKey
      end,
      getCurrentContacts = function()
        return contacts
      end,
      handleContactSelected = function(item)
        liveKey = item and item.conversationKey
      end,
      refreshSelection = function()
        liveKey = nil
      end,
    })
    memory.onSelect(requestItem)
    memory.onTabModeSwapSelection("requests", "whispers")
    assert(liveKey == nil, "Whispers had no selection yet")
    memory.onTabModeSwapSelection("whispers", "requests")
    assert(liveKey == "me::wow::stranger", "Requests tab restores its own selection")
  end
end
