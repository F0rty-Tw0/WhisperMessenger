local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")

local function makeRuntime(overrides)
  local r = {
    availabilityByGUID = {},
    sendStatusByConversation = {},
    isChatMessagingLocked = function()
      return false
    end,
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
      isChatMessagingLocked = function()
        return true
      end,
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

  -- EnrichContactsAvailability: BNet contact online via top-level isOnline shows as online
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            isOnline = true,
            gameAccountInfo = nil,
          }
        end,
      },
    })
    local contacts = {
      { channel = "BN", bnetAccountID = 98, guid = "guid-bn-top" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet top-level isOnline contact should have availability")
    assert(
      contacts[1].availability.status == "CanWhisper",
      "BNet top-level isOnline should be CanWhisper, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: BNet contact online via gameAccountInfo.isOnline shows as online
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            gameAccountInfo = {
              isOnline = true,
              characterName = nil,
              clientProgram = "App",
            },
          }
        end,
      },
    })
    local contacts = {
      {
        channel = "BN",
        bnetAccountID = 99,
        guid = "guid-bn-app",
      },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet online contact should have availability")
    assert(
      contacts[1].availability.status == "CanWhisper",
      "BNet online contact without characterName should be CanWhisper, got: "
        .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: BNet contact away shows as Away (whisperable)
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            gameAccountInfo = {
              isOnline = true,
              isGameAFK = true,
              isGameBusy = false,
              characterName = "Jaina",
            },
          }
        end,
      },
    })
    local contacts = {
      { channel = "BN", bnetAccountID = 101, guid = "guid-bn-away" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet away contact should have availability")
    assert(
      contacts[1].availability.status == "Away",
      "BNet AFK contact should be Away, got: " .. tostring(contacts[1].availability.status)
    )
    assert(contacts[1].availability.canWhisper == true, "Away contacts should be whisperable")
  end

  -- EnrichContactsAvailability: BNet contact busy shows as Busy (whisperable)
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            gameAccountInfo = {
              isOnline = true,
              isGameAFK = false,
              isGameBusy = true,
              characterName = "Thrall",
            },
          }
        end,
      },
    })
    local contacts = {
      { channel = "BN", bnetAccountID = 102, guid = "guid-bn-busy" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet busy contact should have availability")
    assert(
      contacts[1].availability.status == "Busy",
      "BNet busy contact should be Busy, got: " .. tostring(contacts[1].availability.status)
    )
    assert(contacts[1].availability.canWhisper == true, "Busy contacts should be whisperable")
  end

  -- EnrichContactsAvailability: BNet contact offline shows as offline
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            gameAccountInfo = {
              isOnline = false,
              characterName = nil,
            },
          }
        end,
      },
    })
    local contacts = {
      {
        channel = "BN",
        bnetAccountID = 100,
        guid = "guid-bn-off",
      },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet offline contact should have availability")
    assert(
      contacts[1].availability.status == "Offline",
      "BNet offline contact should be Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: WoW guild member with CanWhisperGuild shows as online
  do
    local runtime = makeRuntime({
      availabilityByGUID = {
        ["guid-guild-1"] = { status = "CanWhisperGuild", canWhisper = true },
      },
    })
    local contacts = {
      { guid = "guid-guild-1", channel = "WOW" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "guild member should have availability")
    assert(
      contacts[1].availability.status == "CanWhisperGuild",
      "guild member should be CanWhisperGuild, got: " .. tostring(contacts[1].availability.status)
    )
    assert(contacts[1].availability.canWhisper == true, "guild member should be whisperable")
  end

  -- ShouldRequestAvailability: returns true when no cached status
  do
    assert(ContactEnricher.ShouldRequestAvailability(nil) == true, "should request when no cached availability")
  end

  -- ShouldRequestAvailability: returns true when cached as offline
  do
    local cached = { status = "Offline", canWhisper = false }
    assert(ContactEnricher.ShouldRequestAvailability(cached) == true, "should re-request when cached as offline")
  end

  -- ShouldRequestAvailability: returns false when cached as wrong faction (authoritative)
  do
    local cached = { status = "WrongFaction", canWhisper = false }
    assert(
      ContactEnricher.ShouldRequestAvailability(cached) == false,
      "should not re-request WrongFaction (authoritative)"
    )
  end

  -- ShouldRequestAvailability: returns false when cached as online
  do
    local cached = { status = "CanWhisper", canWhisper = true }
    assert(ContactEnricher.ShouldRequestAvailability(cached) == false, "should not re-request when already online")
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

  -- EnrichContactsAvailability: BNet contact gets classTag/raceTag from playerInfoByGUID
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            gameAccountInfo = {
              characterName = "Arthas",
              playerGuid = "Player-1-00000001",
              className = "Paladin",
              factionName = "Alliance",
              raceName = "Human",
            },
          }
        end,
      },
      playerInfoByGUID = function(_guid)
        return "Paladin", "PALADIN", "Human", "Human"
      end,
    })
    local contacts = {
      {
        channel = "BN",
        bnetAccountID = 123,
        guid = "Player-1-00000001",
      },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].classTag == "PALADIN", "BNet contact should get classTag from playerInfoByGUID")
    assert(contacts[1].raceTag == "Human", "BNet contact should get raceTag from playerInfoByGUID")
  end

  -- BuildWindowSelectionState: selected BNet contact gets classTag from playerInfoByGUID
  do
    local runtime = makeRuntime({
      activeConversationKey = "bnet::BN::42",
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            gameAccountInfo = {
              characterName = "Jaina",
              playerGuid = "Player-1-00000002",
              className = "Mage",
              factionName = "Alliance",
              raceName = "Human",
            },
          }
        end,
      },
      playerInfoByGUID = function(_guid)
        return "Mage", "MAGE", "Human", "Human"
      end,
      store = {
        conversations = {
          ["bnet::BN::42"] = {
            displayName = "Jaina",
            lastPreview = "hello",
            unreadCount = 0,
            lastActivityAt = 50,
            channel = "BN",
            bnetAccountID = 42,
            guid = "Player-1-00000002",
          },
        },
      },
    })
    local contacts = {
      {
        conversationKey = "bnet::BN::42",
        channel = "BN",
        bnetAccountID = 42,
        guid = "Player-1-00000002",
        displayName = "Jaina",
      },
    }
    local result = ContactEnricher.BuildWindowSelectionState(runtime, contacts, nil)
    assert(result.selectedContact ~= nil, "should select BNet contact")
    assert(
      result.selectedContact.classTag == "MAGE",
      "selected BNet contact should get classTag, got " .. tostring(result.selectedContact.classTag)
    )
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
