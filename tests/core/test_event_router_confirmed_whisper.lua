-- A past whisper exchange must not pin a contact "online" once the game or
-- the guild roster says they logged off.

local Store = require("WhisperMessenger.Model.ConversationStore")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local Router = require("WhisperMessenger.Core.EventRouter")

local GUID = "Player-1084-0ABC0003"
local FIVE_MINUTES = 300

local function makeClockState(clock)
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return clock.value
    end,
  }
end

local function makeConfirmedState()
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    availabilityByGUID = {
      [GUID] = { status = "CanWhisper", canWhisper = true, confirmedByWhisper = true },
    },
    pendingOutgoing = {},
    now = function()
      return 1000
    end,
  }
end

return function()
  -- test_offline_response_replaces_whisper_confirmation
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local state = makeConfirmedState()

    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 2 })

    local status = state.availabilityByGUID[GUID].status
    assert(status == "Offline", "definite Offline must replace a whisper confirmation, got " .. tostring(status))
  end

  -- test_wrong_faction_replaces_confirmation_when_roster_says_offline
  do
    PresenceCache._reset()
    PresenceCache._setCache({ [GUID] = "offline" })
    local state = makeConfirmedState()

    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "WrongFaction", rawStatus = 3 })

    local status = state.availabilityByGUID[GUID].status
    assert(status == "WrongFaction", "roster-offline contact must drop the whisper confirmation, got " .. tostring(status))
    PresenceCache._setCache({})
  end

  -- A whisper that just went through outranks a definite Offline for 5 minutes
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local clock = { value = 1000 }
    local state = makeClockState(clock)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", { text = "hi", playerName = "Friend-OtherRealm", lineID = 1, guid = GUID })

    clock.value = 1000 + FIVE_MINUTES - 1
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 2 })
    local status = state.availabilityByGUID[GUID].status
    assert(status == "CanWhisper", "Offline within 5 minutes of a whisper must not replace the confirmation, got " .. tostring(status))

    clock.value = 1000 + FIVE_MINUTES
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 2 })
    status = state.availabilityByGUID[GUID].status
    assert(status == "Offline", "Offline after 5 minutes must apply, got " .. tostring(status))
  end

  -- An incoming whisper counts the same way
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local clock = { value = 2000 }
    local state = makeClockState(clock)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", { text = "hi", playerName = "Friend-OtherRealm", lineID = 2, guid = GUID })

    clock.value = 2060
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 2 })
    local status = state.availabilityByGUID[GUID].status
    assert(status == "CanWhisper", "Offline soon after they whispered must not replace the confirmation, got " .. tostring(status))
  end

  -- The guild/community roster showing them offline still wins inside the window
  do
    PresenceCache._reset()
    PresenceCache._setCache({ [GUID] = "offline" })
    local clock = { value = 3000 }
    local state = makeClockState(clock)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", { text = "hi", playerName = "Friend-OtherRealm", lineID = 3, guid = GUID })

    clock.value = 3010
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 2 })
    local status = state.availabilityByGUID[GUID].status
    assert(status == "Offline", "roster-offline must beat the recent whisper, got " .. tostring(status))
    PresenceCache._setCache({})
  end

  -- A whisper held by the chat lock and replayed later proves only the time it
  -- went through, not the replay time
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local clock = { value = 6000 }
    local state = makeClockState(clock)
    Router.HandleEvent(
      state,
      "CHAT_MSG_WHISPER",
      { text = "hi", playerName = "Friend-OtherRealm", lineID = 4, guid = GUID, replayedAt = 6000 - 1800 }
    )

    clock.value = 6010
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 2 })
    local status = state.availabilityByGUID[GUID].status
    assert(status == "Offline", "a whisper replayed 30 minutes late must not hide Offline, got " .. tostring(status))
  end

  -- An old whisper replayed after a live one keeps the live whisper's proof
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local clock = { value = 6000 }
    local state = makeClockState(clock)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", { text = "live", playerName = "Friend-OtherRealm", lineID = 5, guid = GUID })
    clock.value = 6001
    Router.HandleEvent(
      state,
      "CHAT_MSG_WHISPER",
      { text = "old", playerName = "Friend-OtherRealm", lineID = 6, guid = GUID, replayedAt = 6001 - 1800 }
    )

    clock.value = 6010
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 2 })
    local status = state.availabilityByGUID[GUID].status
    assert(status == "CanWhisper", "a live whisper 10 s ago must still hide Offline, got " .. tostring(status))
  end

  -- A stale replayed whisper does not replace a fresh Offline answer
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local clock = { value = 6000 }
    local state = makeClockState(clock)
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 2 })
    clock.value = 6001
    Router.HandleEvent(
      state,
      "CHAT_MSG_WHISPER",
      { text = "old", playerName = "Friend-OtherRealm", lineID = 7, guid = GUID, replayedAt = 6001 - 1800 }
    )

    local status = state.availabilityByGUID[GUID].status
    assert(status == "Offline", "a whisper from 30 minutes ago must not mark them online, got " .. tostring(status))
  end

  -- A recent replay inside the window still keeps the newer live proof
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local clock = { value = 6000 }
    local state = makeClockState(clock)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", { text = "live", playerName = "Friend-OtherRealm", lineID = 8, guid = GUID })
    clock.value = 6001
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", { text = "old", playerName = "Friend-OtherRealm", lineID = 9, guid = GUID, replayedAt = 5900 })

    clock.value = 6250
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 2 })
    local status = state.availabilityByGUID[GUID].status
    assert(status == "CanWhisper", "the live whisper's proof must survive a recent replay, got " .. tostring(status))
  end

  -- A recent replay's proof runs from when it arrived, not from the replay
  do
    PresenceCache._reset()
    PresenceCache._setCache({})
    local clock = { value = 6000 }
    local state = makeClockState(clock)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", { text = "old", playerName = "Friend-OtherRealm", lineID = 10, guid = GUID, replayedAt = 5800 })

    clock.value = 6150
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 2 })
    local status = state.availabilityByGUID[GUID].status
    assert(status == "Offline", "a replayed whisper's proof must end 5 minutes after it arrived, got " .. tostring(status))
  end
end
