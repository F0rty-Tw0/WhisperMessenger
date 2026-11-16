local FriendList = require("tests.helpers.bnet_friend_list")
local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

-- One BuildWindowSelectionState pass shares one Battle.net resolver cache:
-- the friend list is walked once for all contacts, and the cache is gone
-- when the pass returns.

local STATES = { "wow", "app", "offline", "offline", "offline", "offline", "offline" }

local function newRuntime(states)
  local api, calls = FriendList.NewApi(states)
  local runtime = {
    store = { conversations = {} },
    sendStatusByConversation = {},
    availabilityByGUID = {},
    now = function()
      return 5000
    end,
    bnetApi = api,
  }
  return runtime, calls
end

local function contactsFor(states)
  local contacts = {}
  for id = 1, #states do
    contacts[id] = FriendList.Contact(id)
  end
  return contacts
end

local function statuses(contacts)
  local parts = {}
  for i, contact in ipairs(contacts) do
    parts[i] = contact.availability.status
  end
  return table.concat(parts, ",")
end

return function()
  PresenceCache._reset()
  PresenceCache._setCache({})

  -- test_selection_state_scans_bnet_friend_list_once_per_pass

  do
    local runtime, calls = newRuntime(STATES)
    local contacts = contactsFor(STATES)
    -- a selected offline contact adds the header's own lookup to the pass
    runtime.activeConversationKey = contacts[#contacts].conversationKey
    runtime.store.conversations[runtime.activeConversationKey] = { channel = "BN" }
    ContactEnricher.BuildWindowSelectionState(runtime, contacts)
    assert(calls.friendInfo <= #STATES, "one walk of " .. #STATES .. " friends expected, got " .. calls.friendInfo .. " lookups")
    assert(calls.accountById <= #STATES, "each contact's account is read once per pass, got " .. calls.accountById)
  end

  -- test_selection_state_drops_bnet_pass_cache_after_pass

  do
    local runtime = newRuntime(STATES)
    ContactEnricher.BuildWindowSelectionState(runtime, contactsFor(STATES))
    assert(runtime.bnetPassCache == nil, "the pass cache must not outlive the pass")
  end

  -- test_next_pass_sees_a_friend_who_came_online

  do
    local states = { "wow", "offline", "offline" }
    local runtime = newRuntime(states)
    local first = ContactEnricher.BuildWindowSelectionState(runtime, contactsFor(states))
    assert(statuses(first.contacts) == "CanWhisper,Offline,Offline", statuses(first.contacts))
    states[3] = "app"
    local second = ContactEnricher.BuildWindowSelectionState(runtime, contactsFor(states))
    assert(statuses(second.contacts) == "CanWhisper,Offline,BNetOnline", statuses(second.contacts))
  end

  -- test_pass_does_not_reuse_a_cache_left_behind_by_a_failed_pass

  do
    local states = { "wow", "offline" }
    local runtime = newRuntime(states)
    local ok = pcall(ContactEnricher.BuildWindowSelectionState, runtime, nil, function()
      -- fill the pass cache, then fail before the pass can drop it
      ContactEnricher.EnrichContactsAvailability(contactsFor(states), runtime)
      error("contacts could not be built")
    end)
    assert(not ok, "precondition: the pass failed")
    assert(runtime.bnetPassCache ~= nil, "precondition: the failed pass left its cache behind")
    states[2] = "wow"
    local state = ContactEnricher.BuildWindowSelectionState(runtime, contactsFor(states))
    assert(statuses(state.contacts) == "CanWhisper,CanWhisper", statuses(state.contacts))
    assert(runtime.bnetPassCache == nil, "the pass cache must not outlive the pass")
  end

  -- test_selection_state_statuses_match_the_uncached_enrichment

  do
    local uncachedContacts = contactsFor(STATES)
    ContactEnricher.EnrichContactsAvailability(uncachedContacts, (newRuntime(STATES)))
    local state = ContactEnricher.BuildWindowSelectionState((newRuntime(STATES)), contactsFor(STATES))
    assert(statuses(uncachedContacts) == "CanWhisper,BNetOnline,Offline,Offline,Offline,Offline,Offline", statuses(uncachedContacts))
    assert(statuses(state.contacts) == statuses(uncachedContacts), "pass statuses differ: " .. statuses(state.contacts))
  end
end
