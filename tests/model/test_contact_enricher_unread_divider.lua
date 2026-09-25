local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")

local function build(divider)
  local message = { kind = "user", direction = "in", text = "new" }
  local runtime = {
    activeConversationKey = "A",
    store = { conversations = { A = { messages = { message } }, B = { messages = {} } } },
    sendStatusByConversation = {},
    availabilityByGUID = {},
    unreadDivider = divider and { conversationKey = divider, message = message } or nil,
  }
  local contacts = { { conversationKey = "A", channel = "WOW" }, { conversationKey = "B", channel = "WOW" } }
  return runtime, contacts, message
end

return function()
  -- test_selected_contact_carries_its_unread_divider
  do
    local runtime, contacts, message = build("A")
    local state = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
    assert(state.selectedContact.unreadDividerMessage == message, "selected contact carries the divider message")
  end

  -- test_divider_of_another_conversation_is_ignored
  do
    local runtime, contacts = build("B")
    local state = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
    assert(state.selectedContact.unreadDividerMessage == nil, "a divider for another conversation is not shown")
  end
end
