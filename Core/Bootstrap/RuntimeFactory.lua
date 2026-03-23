local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local Queue = ns.LockdownQueue or require("WhisperMessenger.Model.LockdownQueue")
local Retention = ns.Retention or require("WhisperMessenger.Model.Retention")

local RuntimeFactory = {}

local function currentTime()
  if type(_G.time) == "function" then
    return _G.time()
  end
  return 0
end

-- Build a function that checks if a GUID belongs to the player's guild or communities
-- and returns their online presence. Queries C_Club API live each call so data stays fresh.
-- Returns: "online" (member is online), "offline" (member is offline), or nil (not a member).
function RuntimeFactory.BuildGuildOrCommunityPresenceCheck()
  local clubApi = _G.C_Club
  if type(clubApi) ~= "table" then
    return nil
  end

  local getGuildClubId = clubApi.GetGuildClubId
  local getClubMembers = clubApi.GetClubMembers
  local getMemberInfo = clubApi.GetMemberInfo
  local getSubscribedClubs = clubApi.GetSubscribedClubs

  if type(getClubMembers) ~= "function" or type(getMemberInfo) ~= "function" then
    return nil
  end

  -- Enum.ClubMemberPresence: 0=Unknown, 1=Online, 2=OnlineMobile, 3=Offline, 4=Away
  local function presenceToString(presence)
    if presence == 1 or presence == 2 or presence == 4 then
      return "online"
    end
    return "offline"
  end

  local function checkClubForGUID(clubId, guid)
    local ok, members = pcall(getClubMembers, clubId)
    if not ok or type(members) ~= "table" then
      return nil
    end
    for _, memberId in ipairs(members) do
      local infoOk, info = pcall(getMemberInfo, clubId, memberId)
      if infoOk and info and info.guid == guid then
        return presenceToString(info.presence)
      end
    end
    return nil
  end

  return function(guid)
    if guid == nil then
      return nil
    end

    -- Check guild
    if type(getGuildClubId) == "function" then
      local ok, guildClubId = pcall(getGuildClubId)
      if ok and guildClubId then
        local presence = checkClubForGUID(guildClubId, guid)
        if presence then
          return presence
        end
      end
    end

    -- Check communities
    if type(getSubscribedClubs) == "function" then
      local ok, clubs = pcall(getSubscribedClubs)
      if ok and clubs then
        for _, club in ipairs(clubs) do
          local presence = checkClubForGUID(club.clubId, guid)
          if presence then
            return presence
          end
        end
      end
    end

    return nil
  end
end

function RuntimeFactory.ResolveLocalProfileId(options)
  if options.localProfileId ~= nil then
    return options.localProfileId
  end

  local unitFullName = options.unitFullName or _G.UnitFullName
  local unitName = options.unitName or _G.UnitName
  local getNormalizedRealmName = options.getNormalizedRealmName or _G.GetNormalizedRealmName
  local getRealmName = options.getRealmName or _G.GetRealmName

  local name
  local realmName

  if type(unitFullName) == "function" then
    name, realmName = unitFullName("player")
  elseif type(unitName) == "function" then
    name, realmName = unitName("player")
  end

  if realmName == nil or realmName == "" then
    if type(getNormalizedRealmName) == "function" then
      realmName = getNormalizedRealmName()
    elseif type(getRealmName) == "function" then
      realmName = getRealmName()
    end
  end

  local profileId = Identity.BuildLocalProfileId(name, realmName)
  if profileId ~= nil then
    return profileId
  end

  -- Safe fallback for stripped test environments where player identity APIs are unavailable.
  return "current"
end

function RuntimeFactory.CreateRuntimeState(accountState, characterState, localProfileId, options)
  local store = Store.New({
    maxMessagesPerConversation = options.maxMessagesPerConversation or 200,
    maxConversations = options.maxConversations or 200,
    messageMaxAge = options.messageMaxAge or 86400,
    conversationMaxAge = options.conversationMaxAge or 86400,
  })

  store.conversations = accountState.conversations or {}
  accountState.conversations = store.conversations

  Store.ExpireAll(store, options.now and options.now() or currentTime())

  return {
    accountState = accountState,
    characterState = characterState,
    localProfileId = localProfileId,
    activeConversationKey = characterState.activeConversationKey,
    pendingOutgoing = {},
    sendStatusByConversation = {},
    availabilityByGUID = {},
    chatApi = options.chatApi or _G.C_ChatInfo or {},
    bnetApi = options.bnetApi or _G.C_BattleNet or {},
    playerInfoByGUID = options.playerInfoByGUID or _G.GetPlayerInfoByGUID,
    localFaction = options.localFaction
      or (type(_G.UnitFactionGroup) == "function" and _G.UnitFactionGroup("player") or nil),
    getGuildOrCommunityPresence = options.getGuildOrCommunityPresence
      or RuntimeFactory.BuildGuildOrCommunityPresenceCheck(),
    store = store,
    queue = Queue.New(),
    now = options.now or currentTime,
    isChatMessagingLocked = options.isChatMessagingLocked or function()
      return false
    end,
  }
end

ns.BootstrapRuntimeFactory = RuntimeFactory
return RuntimeFactory
