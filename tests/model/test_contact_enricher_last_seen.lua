local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

-- Last seen: Battle.net contacts carry Blizzard's lastOnlineTime (nil while
-- online); character contacts get our own conversation.lastSeenAt stamped
-- whenever the existing presence refresh sees them online.

local function bnetRuntime(accountInfo)
  return {
    store = { conversations = {} },
    sendStatusByConversation = {},
    availabilityByGUID = {},
    now = function()
      return 5000
    end,
    bnetApi = {
      GetAccountInfoByID = function()
        return accountInfo
      end,
    },
  }
end

return function()
  PresenceCache._reset()
  PresenceCache._setCache({})

  -- test_offline_bnet_friend_carries_last_online_time
  do
    local runtime = bnetRuntime({ bnetAccountID = 42, isOnline = false, lastOnlineTime = 1234 })
    local contact = { conversationKey = "bnet::42", channel = "BN", bnetAccountID = 42 }
    ContactEnricher.EnrichContactsAvailability({ contact }, runtime)
    assert(contact.lastOnlineTime == 1234, "offline friend: Blizzard's last-online time")
  end

  -- test_online_bnet_friend_has_no_last_online_time
  do
    local runtime = bnetRuntime({
      bnetAccountID = 42,
      isOnline = true,
      gameAccountInfo = { isOnline = true, characterName = "Jaina" },
    })
    local contact = { conversationKey = "bnet::42", channel = "BN", bnetAccountID = 42 }
    ContactEnricher.EnrichContactsAvailability({ contact }, runtime)
    assert(contact.lastOnlineTime == nil, "online friend: no last-online time")
  end

  -- test_online_character_contact_stamps_last_seen
  do
    local conversation = { channel = "WOW" }
    local runtime = bnetRuntime(nil)
    runtime.store.conversations["wow::jaina"] = conversation
    runtime.availabilityByGUID["Player-1"] = { status = "CanWhisper", canWhisper = true }
    local contact = { conversationKey = "wow::jaina", channel = "WOW", guid = "Player-1" }
    ContactEnricher.EnrichContactsAvailability({ contact }, runtime)
    assert(conversation.lastSeenAt == 5000, "seen online now, got " .. tostring(conversation.lastSeenAt))
  end

  -- test_offline_character_contact_keeps_old_stamp
  do
    local conversation = { channel = "WOW", lastSeenAt = 10 }
    local runtime = bnetRuntime(nil)
    runtime.store.conversations["wow::jaina"] = conversation
    runtime.availabilityByGUID["Player-1"] = { status = "Offline" }
    local contact = { conversationKey = "wow::jaina", channel = "WOW", guid = "Player-1" }
    ContactEnricher.EnrichContactsAvailability({ contact }, runtime)
    assert(conversation.lastSeenAt == 10, "offline: last-seen unchanged")
  end

  -- test_roster_guess_before_game_answer_does_not_stamp
  do
    PresenceCache._setCache({ ["Player-1"] = "online" })
    local conversation = { channel = "WOW" }
    local runtime = bnetRuntime(nil)
    runtime.store.conversations["wow::jaina"] = conversation
    local contact = { conversationKey = "wow::jaina", channel = "WOW", guid = "Player-1" }
    ContactEnricher.EnrichContactsAvailability({ contact }, runtime)
    assert(conversation.lastSeenAt == nil, "roster guess is not proof, got " .. tostring(conversation.lastSeenAt))
    PresenceCache._setCache({})
  end

  -- test_optimistic_wrong_faction_does_not_stamp
  do
    local conversation = { channel = "WOW" }
    local runtime = bnetRuntime(nil)
    runtime.store.conversations["wow::jaina"] = conversation
    runtime.availabilityByGUID["Player-1"] = { status = "WrongFaction", canWhisper = false }
    local contact = { conversationKey = "wow::jaina", channel = "WOW", guid = "Player-1" }
    ContactEnricher.EnrichContactsAvailability({ contact }, runtime)
    assert(contact.availability.status == "CanWhisper", "precondition: optimistic online")
    assert(conversation.lastSeenAt == nil, "optimistic guess is not proof, got " .. tostring(conversation.lastSeenAt))
  end
end
