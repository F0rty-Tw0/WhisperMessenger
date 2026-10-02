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

  -- test_contacts_fallback_builds_a_full_list
  -- The builder's first argument is the dirty-key set; passing anything there
  -- would turn the fallback build into a partial one.
  local argCount
  ContactEnricher.BuildWindowSelectionState({ sendStatusByConversation = {}, availabilityByGUID = {} }, nil, function(...)
    argCount = select("#", ...)
    return {}
  end)
  assert(argCount == 0, "fallback contact build must pass no dirty keys, got " .. tostring(argCount) .. " args")
end
