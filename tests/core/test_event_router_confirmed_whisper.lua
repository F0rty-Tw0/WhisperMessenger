-- A past whisper exchange must not pin a contact "online" once the game or
-- the guild roster says they logged off.

local Store = require("WhisperMessenger.Model.ConversationStore")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local Router = require("WhisperMessenger.Core.EventRouter")

local GUID = "Player-1084-0ABC0003"

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

    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "Offline", rawStatus = 1 })

    local status = state.availabilityByGUID[GUID].status
    assert(status == "Offline", "definite Offline must replace a whisper confirmation, got " .. tostring(status))
  end

  -- test_wrong_faction_replaces_confirmation_when_roster_says_offline
  do
    PresenceCache._reset()
    PresenceCache._setCache({ [GUID] = "offline" })
    local state = makeConfirmedState()

    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", { guid = GUID, status = "WrongFaction", rawStatus = 2 })

    local status = state.availabilityByGUID[GUID].status
    assert(status == "WrongFaction", "roster-offline contact must drop the whisper confirmation, got " .. tostring(status))
    PresenceCache._setCache({})
  end
end
