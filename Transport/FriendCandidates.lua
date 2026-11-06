local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local GroupChats = ns.GroupChats or require("WhisperMessenger.Model.GroupChats")

-- The people the group chat picker offers: the character friend list and
-- Battle.net friends logged into this same game. Each is
-- { name = <name as group chats keep it>, label = <menu text>, online = bool },
-- online friends first, then by label.
local FriendCandidates = {}

local function trimmed(text)
  if type(text) ~= "string" then
    return nil
  end
  local value = string.match(text, "^%s*(.-)%s*$")
  if value == "" then
    return nil
  end
  return value
end

local function characterFriends(env)
  local friends = {}
  local api = env.friendList
  if type(api) == "table" and type(api.GetNumFriends) == "function" and type(api.GetFriendInfoByIndex) == "function" then
    local okCount, count = pcall(api.GetNumFriends)
    for index = 1, (okCount and tonumber(count) or 0) do
      local ok, info = pcall(api.GetFriendInfoByIndex, index)
      if ok and type(info) == "table" and trimmed(info.name) then
        friends[#friends + 1] = { name = info.name, label = info.name, online = info.connected == true }
      end
    end
    return friends
  end
  -- Older clients: the global friend list functions.
  if type(env.getNumFriends) == "function" and type(env.getFriendInfo) == "function" then
    local okCount, count = pcall(env.getNumFriends)
    for index = 1, (okCount and tonumber(count) or 0) do
      local ok, name, _, _, _, connected = pcall(env.getFriendInfo, index)
      if ok and trimmed(name) then
        friends[#friends + 1] = { name = name, label = name, online = connected == true or connected == 1 }
      end
    end
  end
  return friends
end

local function accountLabel(accountInfo)
  local battleTag = type(accountInfo.battleTag) == "string" and accountInfo.battleTag or nil
  return battleTag and (string.match(battleTag, "^([^#]+)") or battleTag) or nil
end

-- Battle.net friends playing this same game, by their character.
local function battleNetFriends(env)
  local friends = {}
  local api = env.battleNet
  if type(api) ~= "table" or type(api.GetFriendAccountInfo) ~= "function" or type(env.bnGetNumFriends) ~= "function" then
    return friends
  end
  local okCount, count = pcall(env.bnGetNumFriends)
  for index = 1, (okCount and tonumber(count) or 0) do
    local ok, accountInfo = pcall(api.GetFriendAccountInfo, index)
    local game = ok and type(accountInfo) == "table" and accountInfo.gameAccountInfo or nil
    local character = type(game) == "table" and trimmed(game.characterName) or nil
    local sameGame = type(game) == "table"
      and game.isOnline ~= false
      and (game.clientProgram == nil or game.clientProgram == "WoW")
      and (env.projectId == nil or game.wowProjectID == nil or game.wowProjectID == env.projectId)
    if character and sameGame then
      local realm = trimmed(game.realmName)
      local tag = accountLabel(accountInfo)
      friends[#friends + 1] = {
        name = realm and (character .. "-" .. realm) or character,
        label = tag and (character .. " (" .. tag .. ")") or character,
        online = true,
      }
    end
  end
  return friends
end

-- env: friendList (C_FriendList), getNumFriends / getFriendInfo (older
-- clients), battleNet (C_BattleNet), bnGetNumFriends, projectId
-- (WOW_PROJECT_ID), localRealm, selfName, exclude (names to leave out).
function FriendCandidates.Collect(env)
  env = env or {}
  local candidates = {}
  local function add(entry)
    local name = GroupChats.FullName(entry.name, env.localRealm)
    if name == nil or GroupChats.SameName(name, env.selfName) then
      return
    end
    for _, excluded in ipairs(env.exclude or {}) do
      if GroupChats.SameName(name, excluded) then
        return
      end
    end
    for _, existing in ipairs(candidates) do
      if GroupChats.SameName(existing.name, name) then
        existing.online = existing.online or entry.online
        return
      end
    end
    candidates[#candidates + 1] = { name = name, label = entry.label or name, online = entry.online == true }
  end
  for _, entry in ipairs(characterFriends(env)) do
    add(entry)
  end
  for _, entry in ipairs(battleNetFriends(env)) do
    add(entry)
  end
  table.sort(candidates, function(a, b)
    if a.online ~= b.online then
      return a.online
    end
    return string.lower(a.label) < string.lower(b.label)
  end)
  return candidates
end

-- The live game's friend lists, for Collect.
function FriendCandidates.GameEnv(localRealm, selfName, exclude)
  return {
    friendList = _G.C_FriendList,
    getNumFriends = _G.GetNumFriends,
    getFriendInfo = _G.GetFriendInfo,
    battleNet = _G.C_BattleNet,
    bnGetNumFriends = _G.BNGetNumFriends,
    projectId = _G.WOW_PROJECT_ID,
    localRealm = localRealm,
    selfName = selfName,
    exclude = exclude,
  }
end

ns.FriendCandidates = FriendCandidates
return FriendCandidates
