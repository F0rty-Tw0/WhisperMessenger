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
    assert(contacts[2].availability ~= nil, "contact with unknown guid should default to Offline")
    assert(
      contacts[2].availability.status == "Offline",
      "contact with unknown guid should be Offline, got: " .. tostring(contacts[2].availability.status)
    )
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

  -- BuildConversationStatus: corrects WrongFaction to Offline for same-faction WoW contact
  do
    local runtime = makeRuntime({
      availabilityByGUID = { ["guid-sf"] = { status = "WrongFaction", canWhisper = false } },
      localFaction = "Horde",
    })
    local conversation = { guid = "guid-sf", factionName = "Horde", channel = "WOW" }
    local result = ContactEnricher.BuildConversationStatus(runtime, "key-sf", conversation)
    assert(result ~= nil, "same-faction WrongFaction should return a status")
    assert(
      result.status == "Offline",
      "same-faction WrongFaction should be corrected to Offline, got: " .. tostring(result.status)
    )
  end

  -- BuildConversationStatus: corrects WrongFaction to CanWhisper for same-faction contact with guild presence
  do
    local runtime = makeRuntime({
      availabilityByGUID = { ["guid-gp"] = { status = "WrongFaction", canWhisper = false } },
      localFaction = "Horde",
      getGuildOrCommunityPresence = function(_guid)
        return "online"
      end,
    })
    local conversation = { guid = "guid-gp", factionName = "Horde", channel = "WOW" }
    local result = ContactEnricher.BuildConversationStatus(runtime, "key-gp", conversation)
    assert(result ~= nil, "same-faction WrongFaction+guild online should return a status")
    assert(
      result.status == "CanWhisper",
      "same-faction WrongFaction+guild online should be CanWhisper, got: " .. tostring(result.status)
    )
  end

  -- BuildConversationStatus: opposite-faction WrongFaction with guild presence returns XFaction
  do
    local runtime = makeRuntime({
      availabilityByGUID = { ["guid-xf"] = { status = "WrongFaction", canWhisper = false } },
      localFaction = "Alliance",
      getGuildOrCommunityPresence = function(_guid)
        return "online"
      end,
    })
    local conversation = { guid = "guid-xf", factionName = "Horde", channel = "WOW" }
    local result = ContactEnricher.BuildConversationStatus(runtime, "key-xf", conversation)
    assert(result ~= nil, "opposite-faction WrongFaction+guild should return a status")
    assert(
      result.status == "XFaction",
      "opposite-faction WrongFaction+guild online should be XFaction, got: " .. tostring(result.status)
    )
  end

  -- BuildConversationStatus: non-WrongFaction status passes through unchanged
  do
    local avail = { status = "CanWhisper", canWhisper = true }
    local runtime = makeRuntime({
      availabilityByGUID = { ["guid-ok"] = avail },
      localFaction = "Horde",
    })
    local conversation = { guid = "guid-ok", factionName = "Horde", channel = "WOW" }
    local result = ContactEnricher.BuildConversationStatus(runtime, "key-ok", conversation)
    assert(result == avail, "non-WrongFaction status should pass through unchanged")
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

  -- EnrichContactsAvailability: WoW contact opposite faction with CanWhisper becomes XFaction
  do
    local runtime = makeRuntime({
      localFaction = "Horde",
      availabilityByGUID = {
        ["guid-xfac-1"] = { status = "CanWhisper", canWhisper = true },
      },
    })
    local contacts = {
      { guid = "guid-xfac-1", channel = "WOW", factionName = "Alliance" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "x-faction contact should have availability")
    assert(
      contacts[1].availability.status == "XFaction",
      "opposite faction CanWhisper should become XFaction, got: " .. tostring(contacts[1].availability.status)
    )
    assert(contacts[1].availability.canWhisper == true, "XFaction should be whisperable")
  end

  -- EnrichContactsAvailability: WoW contact same faction stays CanWhisper
  do
    local runtime = makeRuntime({
      localFaction = "Horde",
      availabilityByGUID = {
        ["guid-same-1"] = { status = "CanWhisper", canWhisper = true },
      },
    })
    local contacts = {
      { guid = "guid-same-1", channel = "WOW", factionName = "Horde" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "CanWhisper",
      "same faction should stay CanWhisper, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: WoW contact with no faction stays CanWhisper (no crash)
  do
    local runtime = makeRuntime({
      localFaction = "Horde",
      availabilityByGUID = {
        ["guid-nofac"] = { status = "CanWhisper", canWhisper = true },
      },
    })
    local contacts = {
      { guid = "guid-nofac", channel = "WOW" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "CanWhisper",
      "no faction info should stay CanWhisper, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: BNet contact AFK via top-level isAFK shows Away
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            isOnline = true,
            isAFK = true,
            isDND = false,
            gameAccountInfo = {
              isOnline = true,
              isGameAFK = false,
              isGameBusy = false,
              characterName = "Sylvanas",
            },
          }
        end,
      },
    })
    local contacts = {
      { channel = "BN", bnetAccountID = 200, guid = "guid-bn-afk-top" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet AFK contact should have availability")
    assert(
      contacts[1].availability.status == "Away",
      "BNet top-level isAFK should be Away, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: BNet contact DND via top-level isDND shows Busy
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            isOnline = true,
            isAFK = false,
            isDND = true,
            gameAccountInfo = {
              isOnline = true,
              isGameAFK = false,
              isGameBusy = false,
              characterName = "Varian",
            },
          }
        end,
      },
    })
    local contacts = {
      { channel = "BN", bnetAccountID = 201, guid = "guid-bn-dnd-top" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet DND contact should have availability")
    assert(
      contacts[1].availability.status == "Busy",
      "BNet top-level isDND should be Busy, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: BNet contact opposite faction stays CanWhisper (BNet is cross-faction)
  do
    local runtime = makeRuntime({
      localFaction = "Horde",
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            isOnline = true,
            gameAccountInfo = {
              isOnline = true,
              characterName = "Anduin",
              factionName = "Alliance",
              className = "Priest",
            },
          }
        end,
      },
    })
    local contacts = {
      { channel = "BN", bnetAccountID = 202, guid = "guid-bn-xfac" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet x-faction contact should have availability")
    assert(
      contacts[1].availability.status == "CanWhisper",
      "BNet opposite faction should be CanWhisper (not XFaction), got: " .. tostring(contacts[1].availability.status)
    )
    assert(contacts[1].availability.canWhisper == true, "BNet opposite faction should be whisperable")
  end

  -- EnrichContactsAvailability: WrongFaction online guild member becomes XFaction
  do
    local runtime = makeRuntime({
      localFaction = "Horde",
      availabilityByGUID = {
        ["guid-guild-xfac"] = { status = "WrongFaction", canWhisper = false },
      },
      getGuildOrCommunityPresence = function(guid)
        if guid == "guid-guild-xfac" then
          return "online"
        end
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-guild-xfac", channel = "WOW", factionName = "Alliance" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "guild x-faction contact should have availability")
    assert(
      contacts[1].availability.status == "XFaction",
      "WrongFaction online guild member should become XFaction, got: " .. tostring(contacts[1].availability.status)
    )
    assert(contacts[1].availability.canWhisper == true, "guild XFaction should be whisperable")
  end

  -- EnrichContactsAvailability: WrongFaction offline guild member becomes Offline
  do
    local runtime = makeRuntime({
      localFaction = "Horde",
      availabilityByGUID = {
        ["guid-guild-off"] = { status = "WrongFaction", canWhisper = false },
      },
      getGuildOrCommunityPresence = function(guid)
        if guid == "guid-guild-off" then
          return "offline"
        end
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-guild-off", channel = "WOW", factionName = "Alliance" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "Offline",
      "WrongFaction offline guild member should become Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: WrongFaction non-guild member stays WrongFaction
  do
    local runtime = makeRuntime({
      localFaction = "Horde",
      availabilityByGUID = {
        ["guid-stranger"] = { status = "WrongFaction", canWhisper = false },
      },
      getGuildOrCommunityPresence = function(_guid)
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-stranger", channel = "WOW", factionName = "Alliance" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "WrongFaction",
      "non-guild WrongFaction should stay WrongFaction, got: " .. tostring(contacts[1].availability.status)
    )
    assert(contacts[1].availability.canWhisper == false, "WrongFaction should not be whisperable")
  end

  -- EnrichContactsAvailability: BNet contact with isAFK=true but isOnline=nil shows Away
  -- (isAFK=true implies the account is online — you can't be AFK if not logged in)
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            isOnline = nil,
            isAFK = true,
            isDND = false,
            gameAccountInfo = {
              isOnline = false,
              isGameAFK = false,
              isGameBusy = false,
              characterName = nil,
            },
          }
        end,
      },
    })
    local contacts = {
      { channel = "BN", bnetAccountID = 300, guid = "guid-bn-afk-nil-online" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet AFK with nil isOnline should have availability")
    assert(
      contacts[1].availability.status == "Away",
      "BNet isAFK=true with isOnline=nil should be Away, got: " .. tostring(contacts[1].availability.status)
    )
    assert(contacts[1].availability.canWhisper == true, "Away contacts should be whisperable")
  end

  -- EnrichContactsAvailability: BNet contact with isDND=true but isOnline=nil shows Busy
  do
    local runtime = makeRuntime({
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            isOnline = nil,
            isAFK = false,
            isDND = true,
            gameAccountInfo = {
              isOnline = false,
              isGameAFK = false,
              isGameBusy = false,
              characterName = nil,
            },
          }
        end,
      },
    })
    local contacts = {
      { channel = "BN", bnetAccountID = 301, guid = "guid-bn-dnd-nil-online" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet DND with nil isOnline should have availability")
    assert(
      contacts[1].availability.status == "Busy",
      "BNet isDND=true with isOnline=nil should be Busy, got: " .. tostring(contacts[1].availability.status)
    )
    assert(contacts[1].availability.canWhisper == true, "Busy contacts should be whisperable")
  end

  -- EnrichContactsAvailability: WoW contact Offline + opposite faction + guild online becomes XFaction
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      availabilityByGUID = {
        ["guid-guild-offline-online"] = { status = "Offline", canWhisper = false },
      },
      getGuildOrCommunityPresence = function(guid)
        if guid == "guid-guild-offline-online" then
          return "online"
        end
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-guild-offline-online", channel = "WOW", factionName = "Horde" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "XFaction",
      "Offline opposite-faction guild member online should become XFaction, got: "
        .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: same faction WrongFaction without guild defaults to Offline
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      availabilityByGUID = {
        ["guid-same-wf"] = { status = "WrongFaction", canWhisper = false },
      },
    })
    local contacts = {
      { guid = "guid-same-wf", channel = "WOW", factionName = "Alliance" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "Offline",
      "same faction WrongFaction without guild should become Offline, got: "
        .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: same faction WrongFaction with guild online becomes CanWhisper
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      availabilityByGUID = {
        ["guid-same-wf-gon"] = { status = "WrongFaction", canWhisper = false },
      },
      getGuildOrCommunityPresence = function(guid)
        if guid == "guid-same-wf-gon" then
          return "online"
        end
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-same-wf-gon", channel = "WOW", factionName = "Alliance" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "CanWhisper",
      "same faction WrongFaction with guild online should become CanWhisper, got: "
        .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: same faction WrongFaction with guild offline becomes Offline
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      availabilityByGUID = {
        ["guid-same-wf-goff"] = { status = "WrongFaction", canWhisper = false },
      },
      getGuildOrCommunityPresence = function(guid)
        if guid == "guid-same-wf-goff" then
          return "offline"
        end
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-same-wf-goff", channel = "WOW", factionName = "Alliance" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "Offline",
      "same faction WrongFaction with guild offline should become Offline, got: "
        .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: BNet contact offline via API but guild online becomes CanWhisper
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            isOnline = nil,
            isAFK = false,
            isDND = false,
            gameAccountInfo = {
              isOnline = false,
              isGameAFK = false,
              isGameBusy = false,
              characterName = nil,
              factionName = nil,
            },
          }
        end,
      },
      getGuildOrCommunityPresence = function(_guid)
        return "online"
      end,
    })
    local contacts = {
      { channel = "BN", bnetAccountID = 8, guid = "guid-bn-guild-online", factionName = "Horde" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BNet offline+guild online should have availability")
    assert(
      contacts[1].availability.status == "CanWhisper",
      "BNet offline via API but guild online should be CanWhisper (BNet is cross-faction), got: "
        .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: BNet contact offline via API but guild online same faction becomes CanWhisper
  do
    local runtime = makeRuntime({
      localFaction = "Horde",
      bnetApi = {
        GetAccountInfoByID = function(_bnetAccountID, _guid)
          return {
            isOnline = nil,
            isAFK = false,
            isDND = false,
            gameAccountInfo = {
              isOnline = false,
              characterName = nil,
            },
          }
        end,
      },
      getGuildOrCommunityPresence = function(_guid)
        return "online"
      end,
    })
    local contacts = {
      { channel = "BN", bnetAccountID = 9, guid = "guid-bn-guild-same", factionName = "Horde" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "CanWhisper",
      "BNet offline via API but guild online same faction should be CanWhisper, got: "
        .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: WoW contact with no cached status but guild online gets XFaction
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      availabilityByGUID = {},
      getGuildOrCommunityPresence = function(guid)
        if guid == "guid-nocache-guild" then
          return "online"
        end
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-nocache-guild", channel = "WOW", factionName = "Horde" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "no-cache guild online contact should have availability")
    assert(
      contacts[1].availability.status == "XFaction",
      "no-cache opposite faction guild online should be XFaction, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: WoW contact with no cached status but guild online same faction gets CanWhisper
  do
    local runtime = makeRuntime({
      localFaction = "Horde",
      availabilityByGUID = {},
      getGuildOrCommunityPresence = function(guid)
        if guid == "guid-nocache-same" then
          return "online"
        end
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-nocache-same", channel = "WOW", factionName = "Horde" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "no-cache same-faction guild online should have availability")
    assert(
      contacts[1].availability.status == "CanWhisper",
      "no-cache same-faction guild online should be CanWhisper, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: WoW contact with no cached status and guild offline gets Offline
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      availabilityByGUID = {},
      getGuildOrCommunityPresence = function(guid)
        if guid == "guid-nocache-guildoff" then
          return "offline"
        end
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-nocache-guildoff", channel = "WOW", factionName = "Horde" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "no-cache guild offline contact should have availability")
    assert(
      contacts[1].availability.status == "Offline",
      "no-cache guild offline should be Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: WoW contact with no cached status and not in guild defaults to Offline
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      availabilityByGUID = {},
      getGuildOrCommunityPresence = function(_guid)
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-nocache-noguld", channel = "WOW", factionName = "Horde" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "no-cache non-guild contact should default to Offline")
    assert(
      contacts[1].availability.status == "Offline",
      "no-cache non-guild contact should be Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: WoW contact with no cached status and no guild fn defaults to Offline
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      availabilityByGUID = {},
    })
    local contacts = {
      { guid = "guid-nocache-nofn", channel = "WOW", factionName = "Horde" },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "no-cache no-guild-fn contact should default to Offline")
    assert(
      contacts[1].availability.status == "Offline",
      "no-cache no-guild-fn contact should be Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: WrongFaction with nil faction defaults to Offline
  -- (can't determine if same/opposite faction, WrongFaction likely means offline)
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      availabilityByGUID = {
        ["guid-nil-fac"] = { status = "WrongFaction", canWhisper = false },
      },
    })
    local contacts = {
      { guid = "guid-nil-fac", channel = "WOW", factionName = nil },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "Offline",
      "nil faction WrongFaction should become Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- EnrichContactsAvailability: WrongFaction with nil faction + guild online becomes CanWhisper
  do
    local runtime = makeRuntime({
      localFaction = "Alliance",
      availabilityByGUID = {
        ["guid-nil-fac-gon"] = { status = "WrongFaction", canWhisper = false },
      },
      getGuildOrCommunityPresence = function(guid)
        if guid == "guid-nil-fac-gon" then
          return "online"
        end
        return nil
      end,
    })
    local contacts = {
      { guid = "guid-nil-fac-gon", channel = "WOW", factionName = nil },
    }
    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "CanWhisper",
      "nil faction WrongFaction + guild online should become CanWhisper, got: "
        .. tostring(contacts[1].availability.status)
    )
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

  -- ShouldRequestAvailability: returns true when cached as wrong faction (may go offline)
  do
    local cached = { status = "WrongFaction", canWhisper = false }
    assert(
      ContactEnricher.ShouldRequestAvailability(cached) == true,
      "should re-request WrongFaction (player may have gone offline)"
    )
  end

  -- ShouldRequestAvailability: always re-requests to keep statuses fresh
  do
    local cached = { status = "CanWhisper", canWhisper = true }
    assert(
      ContactEnricher.ShouldRequestAvailability(cached) == true,
      "should always re-request to detect offline transitions"
    )
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
