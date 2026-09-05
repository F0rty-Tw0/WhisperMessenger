local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local LivePresence = require("WhisperMessenger.Model.LivePresence")
local Store = require("WhisperMessenger.Model.ConversationStore")

return function()
  local key = "me::WOW::arthas-area52"
  local runtime = {
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    activeConversationKey = key,
    availabilityByGUID = {},
    sendStatusByConversation = {},
    now = function()
      return 100
    end,
  }
  Store.EnsureConversation(runtime.store, key)
  LivePresence.SetTyping(runtime, key, true, 100)
  LivePresence.RecordPeer(runtime, key)

  -- test_selection_state_flags_typing_and_peer_on_contacts_and_selection
  local contacts = {
    { conversationKey = key, displayName = "Arthas", channel = "WOW" },
    { conversationKey = "me::WOW::other", displayName = "Other", channel = "WOW" },
  }
  local state = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
  assert(state.contacts[1].isTyping == true, "typing contact flagged")
  assert(state.contacts[1].peerHasAddon == true, "peer contact flagged")
  assert(not state.contacts[2].isTyping, "other contact not typing")
  assert(not state.contacts[2].peerHasAddon, "other contact not a peer")
  assert(state.selectedContact.isTyping == true, "selected contact flagged typing")
  assert(state.selectedContact.peerHasAddon == true, "selected contact flagged peer")

  -- test_typing_flag_clears_after_ttl
  runtime.now = function()
    return 100 + LivePresence.TYPING_TTL + 1
  end
  local later = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
  assert(not later.contacts[1].isTyping, "typing flag cleared after ttl")
  assert(not later.selectedContact.isTyping, "selected typing flag cleared after ttl")
end
