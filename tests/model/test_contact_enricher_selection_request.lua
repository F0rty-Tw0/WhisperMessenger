local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")

-- A selected request that is not in the contact list (snapshot fallback)
-- still carries isRequest, so the pane shows the request banner.
return function()
  local runtime = {
    activeConversationKey = "A",
    accountState = { settings = { requestsInbox = true } },
    store = { conversations = { A = { channel = "WOW", request = true, messages = {} } } },
    sendStatusByConversation = {},
    availabilityByGUID = {},
  }
  local state = ContactEnricher.BuildWindowSelectionState(runtime, {})
  assert(state.selectedContact.isRequest == true, "fallback snapshot marks the request")

  runtime.accountState.settings.requestsInbox = false
  state = ContactEnricher.BuildWindowSelectionState(runtime, {})
  assert(not state.selectedContact.isRequest, "inbox off: no banner")
end
