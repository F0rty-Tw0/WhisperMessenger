local World = require("tests.helpers.relationship_world")
local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local Store = require("WhisperMessenger.Model.ConversationStore")

local function setup()
  local w = World.New()
  local rt = w.runtime
  rt.store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 })
  rt.availabilityByGUID = {}
  rt.sendStatusByConversation = {}
  return w, rt
end

return function()
  -- test_setting_on_sets_relationship_on_contacts_and_selection
  do
    local w, rt = setup()
    w.guildMembers["Arthas"] = true
    local contacts = { w.item("Player-1-AAA", "Arthas"), w.item("Player-1-BBB", "Jaina") }
    rt.activeConversationKey = contacts[1].conversationKey
    local state = ContactEnricher.BuildWindowSelectionState(rt, contacts)
    assert(state.contacts[1].relationship and state.contacts[1].relationship.primary == "guild", "guildmate flagged")
    assert(state.contacts[2].relationship == nil, "stranger has no relationship")
    assert(state.selectedContact.relationship and state.selectedContact.relationship.primary == "guild", "selection flagged")
  end

  -- no active conversation: the early-return path still enriches the list
  do
    local w, rt = setup()
    w.friendGuids["Player-1-AAA"] = true
    local state = ContactEnricher.BuildWindowSelectionState(rt, { w.item("Player-1-AAA", "Arthas") })
    assert(state.contacts[1].relationship.primary == "friend", "list enriched without a selection")
  end

  -- selected contact built outside the list
  do
    local w, rt = setup()
    w.friendGuids["Player-1-AAA"] = true
    local key = "me::WOW::Arthas"
    Store.EnsureConversation(rt.store, key)
    rt.store.conversations[key].guid = "Player-1-AAA"
    rt.store.conversations[key].displayName = "Arthas"
    rt.activeConversationKey = key
    local state = ContactEnricher.BuildWindowSelectionState(rt, {})
    assert(state.selectedContact.relationship.primary == "friend", "snapshot-built selection flagged")
  end

  -- test_setting_off_clears_relationship_and_calls_no_api (AC 4)
  do
    local w, rt = setup()
    w.guildMembers["Arthas"] = true
    rt.accountState.settings.showRelationshipMarks = false
    local item = w.item("Player-1-AAA", "Arthas")
    item.relationship = { primary = "guild", ties = { "guild" } }
    local before = w.totalCalls()
    ContactEnricher.EnrichContactsRelationship({ item }, rt)
    assert(item.relationship == nil, "setting off clears item.relationship")
    assert(w.totalCalls() == before, "setting off calls no tie API")
  end

  -- missing setting reads as on; nil contacts is fine
  do
    local w, rt = setup()
    w.guildMembers["Arthas"] = true
    rt.accountState = nil
    local item = w.item("Player-1-AAA", "Arthas")
    ContactEnricher.EnrichContactsRelationship({ item }, rt)
    assert(item.relationship and item.relationship.primary == "guild", "no accountState -> on")
    local ok = pcall(ContactEnricher.EnrichContactsRelationship, nil, rt)
    assert(ok, "nil contacts must not raise")
  end

  print("  All ContactEnricher relationship tests passed")
end
