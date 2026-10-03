local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")

-- The selected whisper contact carries isBlocked from the account block list.
local function build(channel, ignored)
  local runtime = {
    activeConversationKey = "A",
    store = { conversations = { A = { messages = {} } } },
    sendStatusByConversation = {},
    availabilityByGUID = {},
    accountState = { filters = { ignored = ignored or {}, rules = {} } },
  }
  local contacts = { { conversationKey = "A", channel = channel, displayName = "Thrall-Durotan" } }
  return runtime, contacts
end

return function()
  -- test_blocked_whisper_contact_is_marked
  do
    local runtime, contacts = build("WOW", { ["thrall-durotan"] = { name = "Thrall-Durotan", blocked = 0 } })
    local state = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
    assert(state.selectedContact.isBlocked == true, "blocked whisper contact is marked")
  end

  -- test_unblocked_whisper_contact_is_not_marked
  do
    local runtime, contacts = build("WOW", {})
    contacts[1].isBlocked = true
    local state = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
    assert(state.selectedContact.isBlocked == false, "an unblocked contact loses the mark")
  end

  -- test_blocked_check_uses_the_character_behind_the_guid
  do
    local saved = rawget(_G, "GetPlayerInfoByGUID")
    rawset(_G, "GetPlayerInfoByGUID", function(guid)
      if guid == "Player-1-A" then
        return "Warrior", "WARRIOR", "Orc", "Orc", 1, "Thrall", "Area 52"
      end
    end)
    local runtime, contacts = build("WOW", { ["thrall-area52"] = { name = "Thrall-Area52", blocked = 0 } })
    contacts[1].displayName = "Boss"
    contacts[1].guid = "Player-1-A"
    local state = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
    rawset(_G, "GetPlayerInfoByGUID", saved)
    assert(state.selectedContact.isBlocked == true, "matches the menu's Block/Unblock name, not the display name")
  end

  -- test_battle_net_contact_is_never_marked
  do
    local runtime, contacts = build("BN", { ["thrall-durotan"] = { name = "Thrall-Durotan", blocked = 0 } })
    local state = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
    assert(not state.selectedContact.isBlocked, "Battle.net contacts are not one character")
  end
end
