local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local Availability = require("WhisperMessenger.Transport.Availability")

return function()
  -- BNet contacts should not inherit WrongFaction from availabilityByGUID.
  -- The status returned by BuildWindowSelectionState should come from the
  -- contact's enriched availability (which uses BNet API), not from the
  -- raw CAN_LOCAL_WHISPER_TARGET_RESPONSE cache.
  local runtime = {
    store = {
      conversations = {
        ["bnet::BN::42"] = {
          channel = "BN",
          bnetAccountID = 42,
          guid = "Player-1234-ABCDEF",
          displayName = "Progidy-Kazzak",
        },
      },
    },
    activeConversationKey = "bnet::BN::42",
    sendStatusByConversation = {},
    availabilityByGUID = {
      ["Player-1234-ABCDEF"] = Availability.FromStatus("WrongFaction"),
    },
    bnetApi = {
      GetAccountInfoByID = function(_bnetAccountID)
        return {
          gameAccountInfo = {
            characterName = "Progidy",
            realmName = "Kazzak",
            factionName = "Horde",
            className = "Hunter",
            playerGuid = "Player-1234-ABCDEF",
          },
        }
      end,
    },
    playerInfoByGUID = nil,
    isChatMessagingLocked = function()
      return false
    end,
  }

  -- Build contacts list with the BNet contact
  local contacts = {
    {
      conversationKey = "bnet::BN::42",
      displayName = "Progidy-Kazzak",
      channel = "BN",
      bnetAccountID = 42,
      guid = "Player-1234-ABCDEF",
      lastPreview = "",
      unreadCount = 0,
      lastActivityAt = 1,
    },
  }

  local result = ContactEnricher.BuildWindowSelectionState(runtime, contacts)

  -- The status should use the contact's enriched availability (CanWhisper),
  -- not the raw WrongFaction from availabilityByGUID
  assert(result.status ~= nil, "status should not be nil")
  assert(
    result.status.status ~= "WrongFaction",
    "BNet status should not be WrongFaction, got: " .. tostring(result.status.status)
  )
  assert(
    result.status.status == "CanWhisper",
    "BNet status should be CanWhisper, got: " .. tostring(result.status.status)
  )

  -- The contact's availability should also be correct
  local contact = result.selectedContact
  assert(contact ~= nil, "selectedContact should exist")
  assert(contact.availability ~= nil, "contact should have availability")
  assert(
    contact.availability.status == "CanWhisper",
    "contact availability should be CanWhisper, got: " .. tostring(contact.availability.status)
  )
end
