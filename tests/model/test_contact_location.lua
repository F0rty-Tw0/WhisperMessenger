local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

local function makeMockClubApi(guildMembers)
  return {
    GetGuildClubId = function()
      return 1
    end,
    GetSubscribedClubs = function()
      return {}
    end,
    GetClubMembers = function(_clubId)
      local ids = {}
      for i = 1, #guildMembers do
        ids[i] = i
      end
      return ids
    end,
    GetMemberInfo = function(_clubId, memberId)
      return guildMembers[memberId]
    end,
  }
end

local function makeBNetRuntime(areaName, activeConversationKey)
  local gameInfo = {
    characterName = "Progidy",
    realmName = "Kazzak",
    factionName = "Horde",
    className = "Hunter",
    playerGuid = "Player-1234-ABCDEF",
  }
  if areaName then
    gameInfo.areaName = areaName
  end
  local conversations = {}
  if activeConversationKey then
    conversations[activeConversationKey] = {
      channel = "BN",
      bnetAccountID = 42,
      guid = "Player-1234-ABCDEF",
      displayName = "Progidy-Kazzak",
    }
  end
  return {
    store = { conversations = conversations },
    activeConversationKey = activeConversationKey,
    sendStatusByConversation = {},
    availabilityByGUID = {},
    bnetApi = {
      GetAccountInfoByID = function(_bnetAccountID)
        return { gameAccountInfo = gameInfo }
      end,
    },
    playerInfoByGUID = nil,
  }
end

local function makeBNetContacts()
  return {
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
end

-- Runs a WoW contact through BuildWindowSelectionState with the given
-- guild presence and returns the resulting areaName.
local function runWoWCase(presence)
  PresenceCache._reset()
  local api = makeMockClubApi({
    { guid = "Player-WoW-1", presence = presence, zone = "Dornogal" },
  })
  PresenceCache._initForTest(api, {
    now = function()
      return 100
    end,
  })

  local runtime = {
    store = { conversations = {} },
    activeConversationKey = nil,
    sendStatusByConversation = {},
    availabilityByGUID = {},
    localFaction = nil,
  }
  local contacts = {
    {
      conversationKey = "wow::guid::Player-WoW-1",
      displayName = "Someone",
      channel = "guid",
      guid = "Player-WoW-1",
      lastPreview = "",
      unreadCount = 0,
      lastActivityAt = 1,
    },
  }
  local result = ContactEnricher.BuildWindowSelectionState(runtime, contacts)
  PresenceCache._reset()
  return result.contacts[1].areaName
end

return function()
  -- BNet contact online in WoW with areaName gets areaName on the contact item
  do
    local result = ContactEnricher.BuildWindowSelectionState(makeBNetRuntime("Voidscar Arena", nil), makeBNetContacts())
    assert(result.contacts[1].areaName == "Voidscar Arena", "BNet contact should carry areaName")
  end

  -- BNet contact with no areaName leaves item.areaName nil
  do
    local result = ContactEnricher.BuildWindowSelectionState(makeBNetRuntime(nil, nil), makeBNetContacts())
    assert(result.contacts[1].areaName == nil, "BNet contact with no areaName should be nil")
  end

  -- WoW contact online in PresenceCache gets areaName from the zone cache
  assert(runWoWCase(1) == "Dornogal", "WoW online contact should carry areaName")

  -- WoW contact offline in PresenceCache leaves areaName nil
  assert(runWoWCase(3) == nil, "WoW offline contact should have nil areaName")

  -- selectedContact built from snapshot (empty contacts list) also gets areaName
  do
    local result = ContactEnricher.BuildWindowSelectionState(makeBNetRuntime("Voidscar Arena", "bnet::BN::42"), {})
    assert(result.selectedContact ~= nil, "selectedContact should be built from snapshot")
    assert(result.selectedContact.areaName == "Voidscar Arena", "selectedContact should carry areaName")
  end

  print("  All contact location tests passed")
end
