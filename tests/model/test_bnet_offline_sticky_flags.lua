local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

return function()
  -- Regression: isAFK/isDND are STICKY on BNet accountInfo; they persist after a
  -- friend goes offline. The enricher must not treat those flags as a proof of
  -- being online — only isOnline (strict) or gameAccountInfo.isOnline/characterName
  -- prove presence.
  PresenceCache._reset()
  PresenceCache._setCache({})

  -- Offline BNet friend with sticky isAFK -> must resolve to Offline
  do
    local runtime = {
      store = { conversations = {} },
      activeConversationKey = nil,
      sendStatusByConversation = {},
      availabilityByGUID = {},
      bnetApi = {
        GetAccountInfoByID = function(_id)
          return {
            bnetAccountID = 42,
            isOnline = false,
            isAFK = true, -- sticky, left over from before going offline
            isDND = false,
            gameAccountInfo = nil,
          }
        end,
      },
      isChatMessagingLocked = function()
        return false
      end,
    }

    local contacts = {
      {
        conversationKey = "bnet::BN::42",
        channel = "BN",
        bnetAccountID = 42,
        guid = "Player-1-AFK",
        displayName = "AFKFriend",
      },
    }

    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "availability should be set")
    assert(
      contacts[1].availability.status == "Offline",
      "offline BNet friend with sticky isAFK must report Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- Offline BNet friend with sticky isDND -> must resolve to Offline
  do
    local runtime = {
      store = { conversations = {} },
      activeConversationKey = nil,
      sendStatusByConversation = {},
      availabilityByGUID = {},
      bnetApi = {
        GetAccountInfoByID = function(_id)
          return {
            bnetAccountID = 43,
            isOnline = false,
            isAFK = false,
            isDND = true, -- sticky
            gameAccountInfo = nil,
          }
        end,
      },
      isChatMessagingLocked = function()
        return false
      end,
    }

    local contacts = {
      {
        conversationKey = "bnet::BN::43",
        channel = "BN",
        bnetAccountID = 43,
        guid = "Player-2-DND",
        displayName = "DNDFriend",
      },
    }

    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "availability should be set")
    assert(
      contacts[1].availability.status == "Offline",
      "offline BNet friend with sticky isDND must report Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- Online BNet friend with isAFK still maps to Away (sticky flag is valid when online)
  do
    local runtime = {
      store = { conversations = {} },
      activeConversationKey = nil,
      sendStatusByConversation = {},
      availabilityByGUID = {},
      bnetApi = {
        GetAccountInfoByID = function(_id)
          return {
            bnetAccountID = 44,
            isOnline = true,
            isAFK = true,
            gameAccountInfo = {
              isOnline = true,
              characterName = "Sleepy",
              realmName = "TestRealm",
              factionName = "Alliance",
              className = "Mage",
            },
          }
        end,
      },
      isChatMessagingLocked = function()
        return false
      end,
    }

    local contacts = {
      {
        conversationKey = "bnet::BN::44",
        channel = "BN",
        bnetAccountID = 44,
        guid = "Player-3-AwayOnline",
        displayName = "SleepyFriend",
      },
    }

    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(
      contacts[1].availability.status == "Away",
      "online BNet friend with isAFK should report Away, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- BNet friend with isOnline=nil and presence cache says "offline" must be Offline,
  -- not BNetOnline. BNetOnline is a "probably on the mobile app" fallback; when we
  -- have an explicit "offline" signal from guild/community presence, trust it.
  do
    PresenceCache._reset()
    PresenceCache._setCache({ ["Player-1305-0B75570B"] = "offline" })
    local runtime = {
      store = { conversations = {} },
      activeConversationKey = nil,
      sendStatusByConversation = {},
      availabilityByGUID = {},
      bnetApi = {
        GetAccountInfoByID = function(_id)
          return {
            bnetAccountID = 9,
            isOnline = nil, -- API hasn't populated yet
            gameAccountInfo = nil,
          }
        end,
      },
      isChatMessagingLocked = function()
        return false
      end,
    }

    local contacts = {
      {
        conversationKey = "bnet::BN::mrgank#2355",
        channel = "BN",
        bnetAccountID = 9,
        guid = "Player-1305-0B75570B",
        displayName = "MrGank#2355",
      },
    }

    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "availability should be set")
    assert(
      contacts[1].availability.status == "Offline",
      "BNet isOnline=nil + presence=offline must report Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end

  -- BNet friend with accountInfo=nil (API has no record) and presence=offline
  -- must report Offline. Currently the enricher leaves availability unset for BN
  -- when ResolveAccountInfo returns nil, so the UI shows stale / no status.
  do
    PresenceCache._reset()
    PresenceCache._setCache({ ["Player-9-NIL"] = "offline" })
    local runtime = {
      store = { conversations = {} },
      activeConversationKey = nil,
      sendStatusByConversation = {},
      availabilityByGUID = {},
      bnetApi = {
        GetAccountInfoByID = function(_id)
          return nil
        end,
        GetAccountInfoByGUID = function(_g)
          return nil
        end,
      },
      isChatMessagingLocked = function()
        return false
      end,
    }

    local contacts = {
      {
        conversationKey = "bnet::BN::ghost",
        channel = "BN",
        bnetAccountID = 99,
        guid = "Player-9-NIL",
        displayName = "Ghost#0001",
      },
    }

    ContactEnricher.EnrichContactsAvailability(contacts, runtime)
    assert(contacts[1].availability ~= nil, "BN contact with nil accountInfo must still get availability")
    assert(
      contacts[1].availability.status == "Offline",
      "BNet accountInfo=nil + presence=offline must report Offline, got: " .. tostring(contacts[1].availability.status)
    )
  end
end
