local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- "Notify when online": per-contact online state seen this session (never
-- saved, so a /reload starts fresh and its first observation only records).
-- Only an observed offline -> online change is worth an alert.
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")

local OnlineWatch = {}

-- Returns true only for an offline -> online change. isOnline nil (unknown)
-- keeps the last known state.
function OnlineWatch.Observe(runtime, conversationKey, isOnline)
  if isOnline == nil or conversationKey == nil then
    return false
  end
  runtime.onlineWatch = runtime.onlineWatch or {}
  local previous = runtime.onlineWatch[conversationKey]
  runtime.onlineWatch[conversationKey] = isOnline
  return previous == false and isOnline == true
end

-- The one writer of conversation.lastSeenAt ("last seen" in the header).
function OnlineWatch.StampSeen(runtime, conversation)
  if conversation ~= nil and type(runtime.now) == "function" then
    conversation.lastSeenAt = runtime.now()
  end
end

-- Friend-list entries use the bare name for same-realm friends.
local function readCharacterFriend(api, name)
  if type(api) ~= "table" or type(api.GetFriendInfo) ~= "function" or type(name) ~= "string" then
    return nil
  end
  local ok, info = pcall(api.GetFriendInfo, name)
  if not (ok and type(info) == "table") then
    local short = Identity.ShortName(name)
    if short ~= name then
      ok, info = pcall(api.GetFriendInfo, short)
    end
  end
  if ok and type(info) == "table" then
    return info.connected == true
  end
  return nil
end

-- BNetStatus loads after this module in the TOC, so resolve it lazily.
local function readBNetFriend(api, conversation)
  local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
  local BNetStatus = ns.ContactEnricherBNetStatus or require("WhisperMessenger.Model.ContactEnricher.BNetStatus")
  local accountInfo = BNetResolver.ResolveAccountInfo(api, conversation.bnetAccountID, conversation.guid, conversation.battleTag)
  return BNetStatus.IsOnline(accountInfo)
end

-- true / false, or nil when WoW does not report it (not a friend, API gone,
-- secret value).
function OnlineWatch.ReadOnline(runtime, conversation)
  if type(conversation) ~= "table" then
    return nil
  end
  if conversation.channel == "BN" then
    if conversation.bnetAccountID == nil or runtime.bnetApi == nil then
      return nil
    end
    local ok, online = pcall(readBNetFriend, runtime.bnetApi, conversation)
    if not ok then
      return nil
    end
    return online
  end
  return readCharacterFriend(runtime.friendListApi, conversation.displayName)
end

-- Menu visibility: WoW reports online state only for character friends and
-- Battle.net friends. A watched contact always shows the entry so it can be
-- turned off.
function OnlineWatch.CanWatch(item, friendListApi)
  if type(item) ~= "table" then
    return false
  end
  if item.notifyOnline == true or item.channel == "BN" then
    return true
  end
  if type(friendListApi) ~= "table" or type(friendListApi.IsFriend) ~= "function" or item.guid == nil then
    return false
  end
  local ok, isFriend = pcall(friendListApi.IsFriend, item.guid)
  return ok and isFriend == true
end

ns.OnlineWatch = OnlineWatch
return OnlineWatch
