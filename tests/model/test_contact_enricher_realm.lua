local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

local function selectBNetFriend(realmName)
  local runtime = {
    availabilityByGUID = {},
    sendStatusByConversation = {},
    activeConversationKey = "bnet::BN::42",
    bnetApi = {
      GetAccountInfoByID = function()
        return {
          gameAccountInfo = {
            clientProgram = "WoW",
            isOnline = true,
            characterName = "Jaina",
            realmName = realmName,
            playerGuid = "Player-1-00000002",
          },
        }
      end,
    },
    store = {
      conversations = {
        ["bnet::BN::42"] = { displayName = "Jaina", channel = "BN", bnetAccountID = 42, guid = "Player-1-00000002" },
      },
    },
  }
  local contacts = {
    { conversationKey = "bnet::BN::42", channel = "BN", bnetAccountID = 42, guid = "Player-1-00000002", displayName = "Jaina" },
  }
  local selected = ContactEnricher.BuildWindowSelectionState(runtime, contacts, nil).selectedContact
  assert(selected ~= nil, "BNet friend should be selected")
  return selected
end

return function()
  PresenceCache._reset()
  PresenceCache._setCache({})
  local wasForever = FlavorCompat.isForever

  -- Retail and Classic: the BNet friend's realm shows next to the name.
  FlavorCompat.isForever = false
  local contact = selectBNetFriend("Silvermoon")
  assert(contact.characterName == "Jaina", "character name should come from BNet, got " .. tostring(contact.characterName))
  assert(contact.realm == "Silvermoon", "realm should come from BNet, got " .. tostring(contact.realm))

  -- WoW: Forever: BNet reports an internal server id (CAMWOWEU5Realm8PvP),
  -- not a realm a player knows, so it is dropped.
  FlavorCompat.isForever = true
  contact = selectBNetFriend("CAMWOWEU5Realm8PvP")
  FlavorCompat.isForever = wasForever
  assert(contact.characterName == "Jaina", "character name should stay on Forever, got " .. tostring(contact.characterName))
  assert(contact.realm == nil, "Forever should drop the BNet realm, got " .. tostring(contact.realm))
end
