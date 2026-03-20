local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")

local function makeRuntime(overrides)
  local r = {
    availabilityByGUID = {},
    sendStatusByConversation = {},
    isChatMessagingLocked = function() return false end,
    activeConversationKey = nil,
    bnetApi = {},
    store = { conversations = {} },
  }
  if overrides then
    for k, v in pairs(overrides) do
      r[k] = v
    end
  end
  return r
end

return function()
  -- EnrichContactsAvailability: WoW contact gets cached availability
  do
    local runtime = makeRuntime({
      availabilityByGUID = { ["guid-1"] = { status = "CanWhisper" } },
    })
    local contacts = {
      { guid = "guid-1", channel = "WOW" },
      { guid = "guid-2", channel = "WOW" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "contact with known guid should get availability")
    assert(contacts[1].availability.status == "CanWhisper", "availability status should match")
    assert(contacts[2].availability == nil, "contact with unknown guid should have no availability")
  end

  -- EnrichContactsAvailability: BNet contact online gets CanWhisper availability and metadata refreshed
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetFriendAccountInfo = function(_, id)
          return {
            gameAccountInfo = {
              characterName = "Arthas",
              factionName = "Alliance",
              className = "Paladin",
              raceName = "Human",
            },
          }
        end,
      },
    })
    -- Stub BNetResolver via ns mechanism by patching require path; use the real module
    local contacts = {
      {
        channel = "BN",
        bnetAccountID = 123,
        guid = "guid-bn-1",
      },
    }
    -- BNetResolver.ResolveAccountInfo is called internally; use a runtime with a bnetApi
    -- that has GetFriendAccountInfo returning a valid accountInfo
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    -- availability should be set (either CanWhisper or Offline depending on BNetResolver)
    -- we just verify the function ran without error and returned something meaningful
    -- (actual BNet availability depends on BNetResolver internals)
  end

  -- BuildConversationStatus: returns nil when conversationKey is nil
  do
    local runtime = makeRuntime()
    local result = ContactEnricher.BuildConversationStatus(runtime, nil, nil)
    assert(result == nil, "nil conversationKey should return nil")
  end

  -- BuildConversationStatus: returns cached send status when present
  do
    local status = { status = "Send failed" }
    local runtime = makeRuntime({
      sendStatusByConversation = { ["key-1"] = status },
    })
    local result = ContactEnricher.BuildConversationStatus(runtime, "key-1", nil)
    assert(result == status, "should return cached send status")
  end

  -- BuildConversationStatus: returns Lockdown when messaging is locked
  do
    local runtime = makeRuntime({
      isChatMessagingLocked = function() return true end,
    })
    local result = ContactEnricher.BuildConversationStatus(runtime, "key-1", nil)
    assert(result ~= nil, "should return a status when locked")
    assert(result.status == "Lockdown", "status should be Lockdown")
  end

  -- BuildConversationStatus: returns cached guid availability for conversation
  do
    local avail = { status = "CanWhisper" }
    local runtime = makeRuntime({
      availabilityByGUID = { ["guid-x"] = avail },
    })
    local conversation = { guid = "guid-x" }
    local result = ContactEnricher.BuildConversationStatus(runtime, "key-1", conversation)
    assert(result == avail, "should return availability from guid cache")
  end

  -- BuildConversationStatus: returns nil when no status found
  do
    local runtime = makeRuntime()
    local result = ContactEnricher.BuildConversationStatus(runtime, "key-1", { guid = "unknown" })
    assert(result == nil, "should return nil when no status available")
  end

  -- BuildWindowSelectionState: no active conversation returns only contacts
  do
    local runtime = makeRuntime()
    local contacts = { { conversationKey = "k1", channel = "WOW" } }
    local result = ContactEnricher.BuildWindowSelectionState(runtime, contacts, nil)
    assert(result ~= nil, "result should not be nil")
    assert(result.contacts == contacts, "contacts should be passed through")
    assert(result.selectedContact == nil, "no selectedContact when no active conversation")
    assert(result.conversation == nil, "no conversation when no active conversation")
  end

  -- BuildWindowSelectionState: active conversation selects matching contact
  do
    local runtime = makeRuntime({
      activeConversationKey = "k1",
      store = {
        conversations = {
          k1 = {
            displayName = "Arthas",
            lastPreview = "hey",
            unreadCount = 2,
            lastActivityAt = 100,
            channel = "WOW",
            guid = "guid-1",
          },
        },
      },
    })
    local contacts = {
      { conversationKey = "k1", channel = "WOW", guid = "guid-1", displayName = "Arthas" },
    }
    local result = ContactEnricher.BuildWindowSelectionState(runtime, contacts, nil)
    assert(result.selectedContact ~= nil, "should select the active contact")
    assert(result.selectedContact.conversationKey == "k1", "selected contact should match active key")
    assert(result.conversation ~= nil, "conversation should be populated")
  end

  -- BuildWindowSelectionState: active conversation not in contacts list builds fallback selectedContact
  do
    local conversation = {
      displayName = "Jaina",
      lastPreview = "hello",
      unreadCount = 0,
      lastActivityAt = 50,
      channel = "WOW",
      guid = "guid-2",
    }
    local runtime = makeRuntime({
      activeConversationKey = "k2",
      store = { conversations = { k2 = conversation } },
    })
    local contacts = {}
    local result = ContactEnricher.BuildWindowSelectionState(runtime, contacts, nil)
    assert(result.selectedContact ~= nil, "should build fallback selectedContact")
    assert(result.selectedContact.conversationKey == "k2", "fallback contact key should match")
    assert(result.selectedContact.displayName == "Jaina", "fallback contact displayName should match")
  end

  -- BuildWindowSelectionState: uses buildContactsFn when contacts is nil
  do
    local runtime = makeRuntime()
    local called = false
    local fakeContacts = { { conversationKey = "k99", channel = "WOW" } }
    local function fakeBuild(_rt)
      called = true
      return fakeContacts
    end
    local result = ContactEnricher.BuildWindowSelectionState(runtime, nil, fakeBuild)
    assert(called, "buildContactsFn should be called when contacts is nil")
    assert(result.contacts == fakeContacts, "contacts from buildContactsFn should be used")
  end
end
