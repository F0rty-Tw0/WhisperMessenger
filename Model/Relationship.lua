local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- How the player knows a contact: Battle.net friend > guild > character friend
-- > shared community. Resolve decides the ties, caches them on the runtime and
-- never throws; a tie whose API is missing, throws or answers a secret value
-- is simply absent.
local Relationship = {}

local CACHE_SECONDS = 300
local WOW_TIES = { "bnet", "guild", "friend", "community" }
-- A BNet chat is always bnet; its friend's character is checked for these.
local BNET_TIES = { "guild", "community" }

-- PresenceCache, BNetResolver and BNetStatus load after this file's
-- neighbours or after the files that use it, so they resolve at call time.
local function presenceCache()
  return ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")
end

local function bnetResolver()
  return ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
end

local function bnetStatus()
  return ns.ContactEnricherBNetStatus or require("WhisperMessenger.Model.ContactEnricher.BNetStatus")
end

local function isForever()
  local flavor = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
  return flavor.isForever == true
end

local function isUsableString(value)
  return type(value) == "string" and not SecretValue.Is(value)
end

-- First return of fn(...), or nil. A throw or a secret answer marks the whole
-- resolve unreliable so it is returned but never cached.
local function call(ctx, fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, value = pcall(fn, ...)
  if not ok or SecretValue.Is(value) then
    ctx.reliable = false
    return nil
  end
  return value
end

local function readGuildName(ctx)
  local name = call(ctx, _G.GetGuildInfo, "player")
  if isUsableString(name) and name ~= "" then
    ctx.guildName = name
  end
end

local function isGuildMember(ctx)
  local api = _G.C_GuildInfo
  if type(api) ~= "table" or not ctx.nameOk then
    return false
  end
  -- Forever: the roster knows a guildmate only by the bare name (names never hold "-").
  -- Elsewhere a bare name is the own-realm namesake, a different character.
  if call(ctx, api.MemberExistsByName, ctx.name) ~= true then
    if not isForever() then
      return false
    end
    local short = ctx.name:match("^(.+)%-[^%-]+$") or ctx.name
    if short == ctx.name or call(ctx, api.MemberExistsByName, short) ~= true then
      return false
    end
  end
  readGuildName(ctx)
  return true
end

local function isBNetFriend(ctx)
  local api = ctx.runtime.bnetApi
  if type(api) ~= "table" then
    return false
  end
  return type(call(ctx, api.GetAccountInfoByGUID, ctx.guid)) == "table"
end

local function isCharacterFriend(ctx)
  local api = _G.C_FriendList
  if type(api) ~= "table" then
    return false
  end
  if call(ctx, api.IsFriend, ctx.guid) == true then
    return true
  end
  if not ctx.nameOk then
    return false
  end
  -- Through call(), so a throwing lookup marks the result unreliable.
  -- Same-realm friends are listed under the bare name.
  if type(call(ctx, api.GetFriendInfo, ctx.name)) == "table" then
    return true
  end
  local short = Identity.ShortName(ctx.name)
  return short ~= ctx.name and type(call(ctx, api.GetFriendInfo, short)) == "table"
end

local function readCommunityName(ctx, clubId)
  local api = _G.C_Club
  if type(api) ~= "table" then
    return
  end
  local info = call(ctx, api.GetClubInfo, clubId)
  if type(info) ~= "table" then
    return
  end
  local ok, name = pcall(function()
    return info.name
  end)
  if ok and isUsableString(name) and name ~= "" then
    ctx.communityName = name
  end
end

local function isInCommunity(ctx)
  local clubId = call(ctx, presenceCache().GetCommunityClubId, ctx.guid)
  if clubId == nil then
    return false
  end
  readCommunityName(ctx, clubId)
  return true
end

local CHECKS = {
  guild = isGuildMember,
  bnet = isBNetFriend,
  friend = isCharacterFriend,
  community = isInCommunity,
}

-- Who is checked and under which cache key, or nil when no mark applies.
-- rawName becomes the checked name in gather, so a cache hit skips the lookup.
local function whisperTarget(item)
  local guid = item.guid
  if not isUsableString(guid) then
    return nil
  end
  return { guid = guid, rawName = item.displayName, key = item.conversationKey, ties = WOW_TIES }
end

-- A BNet chat checks the friend's current character, or nil when the friend
-- is not in WoW on one. Never uses realmName: Forever reports a server id there.
local function bnetChatTarget(item, runtime)
  local accountInfo = bnetResolver().ResolveAccountInfo(runtime.bnetApi, item.bnetAccountID, item.guid, item.battleTag or item.displayName)
  ---@type table?
  local gameInfo = type(accountInfo) == "table" and accountInfo.gameAccountInfo or nil
  if type(gameInfo) ~= "table" or not bnetStatus().IsInWoW(gameInfo) then
    return nil
  end
  local guid = gameInfo.playerGuid
  if not isUsableString(guid) then
    return nil
  end
  local key = isUsableString(item.conversationKey) and (item.conversationKey .. "|" .. guid) or nil
  return { guid = guid, rawName = gameInfo.characterName, key = key, known = "bnet", ties = BNET_TIES }
end

local function buildTarget(item, runtime)
  if item.channel == "WOW" then
    return whisperTarget(item)
  end
  return bnetChatTarget(item, runtime)
end

-- BNet chat with the friend offline, elsewhere or unresolvable: no API call, never cached.
local function bnetOnly()
  return { primary = "bnet", ties = { "bnet" } }
end

local function now(runtime)
  if type(runtime.now) == "function" then
    return runtime.now()
  end
  return 0
end

-- Entries live in cache.entries; the whole table is dropped when
-- PresenceCache rebuilt its index since it was filled.
local function entriesOf(runtime)
  local cache = runtime.relationshipCache
  if type(cache) ~= "table" then
    cache = {}
    runtime.relationshipCache = cache
  end
  local generation = presenceCache().IndexGeneration()
  if cache.entries == nil or cache.generation ~= generation then
    cache.entries = {}
    cache.generation = generation
  end
  return cache.entries
end

local function gather(target, runtime)
  local name = IgnoreList.CharacterName(target.rawName, target.guid)
  local ctx = {
    runtime = runtime,
    guid = target.guid,
    name = name,
    nameOk = isUsableString(name),
    reliable = true,
  }
  if not ctx.nameOk then
    ctx.reliable = false
  end
  local ties = { target.known }
  for _, tie in ipairs(target.ties) do
    if CHECKS[tie](ctx) then
      ties[#ties + 1] = tie
    end
  end
  if #ties == 0 then
    return nil, ctx.reliable
  end
  local rel = { primary = ties[1], ties = ties, guildName = ctx.guildName, communityName = ctx.communityName }
  return rel, ctx.reliable
end

function Relationship.Resolve(item, runtime)
  if type(item) ~= "table" or type(runtime) ~= "table" then
    return nil
  end
  if item.channel ~= "WOW" and item.channel ~= "BN" then
    return nil
  end
  local built, target = pcall(buildTarget, item, runtime)
  if not built or target == nil then
    return item.channel == "BN" and bnetOnly() or nil
  end
  local entries = target.key ~= nil and entriesOf(runtime) or nil
  local at = now(runtime)
  local entry = entries and entries[target.key]
  if entry and at - entry.at < CACHE_SECONDS then
    return entry.value or nil
  end
  local rel, reliable = gather(target, runtime)
  if entries and reliable then
    entries[target.key] = { value = rel or false, at = at }
  end
  return rel
end

function Relationship.Invalidate(runtime)
  runtime.relationshipCache = {}
end

function Relationship.IsEnabled(runtime)
  local accountState = type(runtime) == "table" and runtime.accountState or nil
  local settings = type(accountState) == "table" and accountState.settings or nil
  if type(settings) ~= "table" then
    return true
  end
  return settings.showRelationshipMarks ~= false
end

local function namedLine(label, namedLabel, name)
  if name ~= nil then
    return string.format(Localization.Text(namedLabel), name)
  end
  return Localization.Text(label)
end

local LINES = {
  guild = function(rel)
    return namedLine("Guild", "Guild: %s", rel.guildName)
  end,
  bnet = function()
    return Localization.Text("Battle.net friend")
  end,
  friend = function()
    return Localization.Text("Friend")
  end,
  community = function(rel)
    return namedLine("Community", "Community: %s", rel.communityName)
  end,
}

function Relationship.TooltipLines(rel)
  local lines = {}
  if type(rel) ~= "table" then
    return lines
  end
  for _, tie in ipairs(rel.ties or {}) do
    local line = LINES[tie]
    if line then
      lines[#lines + 1] = line(rel)
    end
  end
  return lines
end

ns.Relationship = Relationship

return Relationship
