local Availability = require("WhisperMessenger.Transport.Availability")
local BNetResolver = require("WhisperMessenger.Transport.BNetResolver")
local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

-- Enum.ChatWhisperTargetStatus (game): CanWhisper=0, CanWhisperGuild=1, Offline=2, WrongFaction=3
local CODE_CAN_WHISPER_GUILD = 1
local CODE_OFFLINE = 2
local CODE_WRONG_FACTION = 3

local GUID = "Player-1-0001"

local function makeRuntime(code, bnetApi)
  local status = BNetResolver.NormalizeAvailabilityStatus(code)

  return {
    availabilityByGUID = { [GUID] = Availability.FromStatus(status) },
    sendStatusByConversation = {},
    bnetApi = bnetApi or {},
    store = { conversations = {} },
    localFaction = "Horde",
  }
end

local function enrich(code, factionName, bnetApi)
  local runtime = makeRuntime(code, bnetApi)
  local contacts = { { guid = GUID, channel = "WOW", displayName = "Someone-Realm", factionName = factionName } }
  ContactEnricher.EnrichContactsAvailability(contacts, runtime)

  return contacts[1].availability.status
end

local function headerStatus(code, factionName)
  local runtime = makeRuntime(code)
  local conversation = { guid = GUID, displayName = "Someone-Realm", factionName = factionName, channel = "WOW" }

  return ContactEnricher.BuildConversationStatus(runtime, "key", conversation).status
end

local function withGroup(names, connected, fn)
  local saved = {
    UnitIsConnected = _G.UnitIsConnected,
    UnitName = _G.UnitName,
    GetNumGroupMembers = _G.GetNumGroupMembers,
    IsInRaid = _G.IsInRaid,
  }
  rawset(_G, "UnitIsConnected", function()
    return connected
  end)
  rawset(_G, "UnitName", function(unit)
    return names[tonumber(unit:match("%d+"))]
  end)
  rawset(_G, "GetNumGroupMembers", function()
    return #names
  end)
  rawset(_G, "IsInRaid", function()
    return false
  end)
  local ok, err = pcall(fn)
  for key, value in pairs(saved) do
    rawset(_G, key, value)
  end
  assert(ok, err)
end

return function()
  -- Same-faction Offline (game code 2) with no proof stays Offline
  PresenceCache._reset()
  PresenceCache._setCache({})
  assert(enrich(CODE_OFFLINE, "Horde") == "Offline", "same-faction offline with no proof should be Offline")
  assert(enrich(CODE_OFFLINE, nil) == "Offline", "unknown-faction offline with no proof should be Offline")
  assert(headerStatus(CODE_OFFLINE, "Horde") == "Offline", "header: same-faction offline with no proof should be Offline")

  -- Guild/community roster showing them online beats the whisper check
  PresenceCache._reset()
  PresenceCache._setCache({ [GUID] = "online" })
  assert(enrich(CODE_OFFLINE, "Horde") == "CanWhisper", "same-faction offline + roster online should be CanWhisper")
  assert(headerStatus(CODE_OFFLINE, "Horde") == "CanWhisper", "header: roster online should be CanWhisper")

  -- Roster showing them offline stays Offline
  PresenceCache._reset()
  PresenceCache._setCache({ [GUID] = "offline" })
  assert(enrich(CODE_OFFLINE, "Horde") == "Offline", "same-faction offline + roster offline should be Offline")

  -- An online BNet friend proves reachability
  PresenceCache._reset()
  PresenceCache._setCache({})
  local onlineFriend = {
    GetAccountInfoByGUID = function()
      return { isOnline = true }
    end,
  }
  local awayFriend = {
    GetAccountInfoByGUID = function()
      return { isOnline = true, isAFK = true }
    end,
  }
  assert(enrich(CODE_OFFLINE, "Horde", onlineFriend) == "CanWhisper", "offline + online BNet friend should be CanWhisper")
  assert(enrich(CODE_OFFLINE, "Horde", awayFriend) == "Away", "offline + AFK BNet friend should be Away")

  -- A connected party member proves reachability
  withGroup({ "Someone" }, true, function()
    assert(enrich(CODE_OFFLINE, "Horde") == "CanWhisper", "offline + connected group member should be CanWhisper")
  end)
  withGroup({ "Someone" }, false, function()
    assert(enrich(CODE_OFFLINE, "Horde") == "Offline", "offline + disconnected group member should be Offline")
  end)

  -- Game code 1 (CanWhisperGuild): reachable; opposite faction shows XFaction
  PresenceCache._reset()
  PresenceCache._setCache({})
  assert(enrich(CODE_CAN_WHISPER_GUILD, "Alliance") == "XFaction", "cross-faction guild code should be XFaction")
  assert(enrich(CODE_CAN_WHISPER_GUILD, "Horde") == "CanWhisper", "same-faction guild code should be CanWhisper")
  assert(headerStatus(CODE_CAN_WHISPER_GUILD, "Alliance") == "XFaction", "header: cross-faction guild code should be XFaction")
  assert(enrich(CODE_CAN_WHISPER_GUILD, nil) == "XFaction", "unknown-faction guild code should be XFaction")
  assert(headerStatus(CODE_CAN_WHISPER_GUILD, nil) == "XFaction", "header: unknown-faction guild code should be XFaction")
  assert(headerStatus(CODE_CAN_WHISPER_GUILD, "Horde") == "CanWhisper", "header: same-faction guild code should be CanWhisper")

  -- Code 1 proves nothing about faction: nothing is inferred or saved
  local conversation = { guid = GUID, displayName = "Someone-Realm", channel = "WOW" }
  local guildRuntime = makeRuntime(CODE_CAN_WHISPER_GUILD)
  guildRuntime.store = { conversations = { key = conversation } }
  local guildItem = { guid = GUID, channel = "WOW", displayName = "Someone-Realm", conversationKey = "key" }
  ContactEnricher.EnrichContactsAvailability({ guildItem }, guildRuntime)
  assert(guildItem.factionName == nil, "guild code must not infer the item's faction")
  assert(conversation.factionName == nil, "guild code must not persist a faction")

  -- Game code 3 (WrongFaction) keeps the optimistic fallback for same faction
  assert(enrich(CODE_WRONG_FACTION, "Horde") == "CanWhisper", "same-faction WrongFaction keeps optimistic CanWhisper")
  assert(enrich(CODE_WRONG_FACTION, "Alliance") == "WrongFaction", "opposite-faction WrongFaction stays WrongFaction")

  -- Opposite-faction real Offline without presence is unchanged
  assert(enrich(CODE_OFFLINE, "Alliance") == "WrongFaction", "opposite-faction offline without presence is unchanged")

  PresenceCache._reset()
end
