local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

-- Replying to a message request accepts it (the conversation leaves the
-- Requests tab). The chat must follow it to Whispers and stay open, the same
-- as clicking Accept, instead of the pane going blank.

local KEY = "me::wow::stranger"

local function build(tabMode, item)
  local tabCalls, selected = {}, {}
  local window = {
    frame = {
      IsShown = function()
        return true
      end,
    },
    refreshSelection = function() end,
    getTabMode = function()
      return tabMode
    end,
    setTabMode = function(mode)
      tabCalls[#tabCalls + 1] = mode
      tabMode = mode
    end,
  }
  local coordinator = WindowCoordinator.Create({
    runtime = {
      availabilityByGUID = {},
      availabilityRequestedAt = {},
      now = function()
        return 1000
      end,
      chatApi = {},
      activeConversationKey = KEY,
      store = { conversations = { [KEY] = { channel = "WOW" } } },
    },
    buildContacts = function()
      return { item }
    end,
    getWindow = function()
      return window
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
    selectConversation = function(key)
      selected[#selected + 1] = key
      return { selectedContact = item, contacts = { item } }
    end,
  })
  return coordinator, tabCalls, selected
end

return function()
  -- test_reply_from_requests_switches_to_whispers_and_keeps_chat_open
  do
    local item = { conversationKey = KEY, channel = "WOW", isRequest = true }
    local coordinator, tabCalls, selected = build("requests", item)
    coordinator.refreshContacts()
    item.isRequest = nil -- the reply accepted it
    local state = coordinator.refreshContacts()
    assert(tabCalls[1] == "whispers", "switched to the Whispers tab")
    assert(selected[1] == KEY, "the replied-to chat is selected again there")
    assert(state.selectedContact == item, "the pane keeps showing the chat")
  end

  -- test_request_still_on_requests_tab_is_untouched
  do
    local item = { conversationKey = KEY, channel = "WOW", isRequest = true }
    local coordinator, tabCalls, selected = build("requests", item)
    local state = coordinator.refreshContacts()
    assert(#tabCalls == 0 and #selected == 0, "no tab switch while still a request")
    assert(state.selectedContact == item, "request stays selected")
  end

  -- test_incoming_message_never_leaves_requests_for_a_stale_whisper
  -- The remembered selection is a plain whisper (it never was a request):
  -- a refresh (e.g. a new request arriving) must not switch tabs.
  do
    local item = { conversationKey = KEY, channel = "WOW" }
    local coordinator, tabCalls, selected = build("requests", item)
    coordinator.refreshContacts()
    local state = coordinator.refreshContacts()
    assert(#tabCalls == 0 and #selected == 0, "stays on the Requests tab")
    assert(state.selectedContact == nil, "off-tab whisper dropped from the pane")
  end

  -- test_groups_tab_still_drops_whisper_selection
  do
    local item = { conversationKey = KEY, channel = "WOW" }
    local coordinator, tabCalls = build("groups", item)
    local state = coordinator.refreshContacts()
    assert(#tabCalls == 0, "only Requests follows the conversation")
    assert(state.selectedContact == nil, "off-tab whisper still dropped on Groups")
  end
end
