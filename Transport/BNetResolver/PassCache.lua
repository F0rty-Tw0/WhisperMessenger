local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FriendScan = ns.BNetResolverFriendScan or require("WhisperMessenger.Transport.BNetResolver.FriendScan")

-- Resolver cache for one synchronous pass over the contacts (one window
-- refresh, one friend scan). It remembers what BNetResolver.ResolveAccountInfo answered and
-- walks the Battle.net friend list once instead of once per contact.
-- Friend state changes between frames, so the caller must drop the cache
-- before the pass returns. One cache serves one bnetApi.
local PassCache = {}

-- sanitizeAccountID: BNetResolver.SanitizeAccountID, handed in because the
-- resolver loads after this file.
function PassCache.New(sanitizeAccountID)
  return { results = {}, index = nil, sanitizeAccountID = sanitizeAccountID }
end

-- Results are kept per account ID, guid and battle tag. Account IDs are
-- session-scoped, so two saved chats can carry the same stale ID for
-- different friends; the battle tag tells them apart.
local function findResult(passCache, bnetAccountID, guid, battleTag)
  local entries = passCache.results[bnetAccountID]
  if entries == nil then
    return nil
  end
  for _, entry in ipairs(entries) do
    if entry.guid == guid and entry.battleTag == battleTag then
      return entry
    end
  end
  return nil
end

-- Returns found, accountInfo. found is true for a remembered miss as well.
function PassCache.Lookup(passCache, bnetAccountID, guid, battleTag)
  local entry = findResult(passCache, bnetAccountID, guid, battleTag)
  if entry == nil then
    return false, nil
  end
  return true, entry.accountInfo
end

-- accountInfo may be nil: an unresolved account is remembered too.
function PassCache.Remember(passCache, bnetAccountID, guid, battleTag, accountInfo)
  local entries = passCache.results[bnetAccountID]
  if entries == nil then
    entries = {}
    passCache.results[bnetAccountID] = entries
  end
  entries[#entries + 1] = { guid = guid, battleTag = battleTag, accountInfo = accountInfo }
  return accountInfo
end

-- One walk of the friend list. Matches the uncached FriendScan lookups: the
-- first friend with an ID or battle tag wins, and a friend whose lookup
-- fails is skipped. available is false when the list could not be read.
local function buildIndex(bnetApi, sanitizeAccountID)
  local index = { byAccountId = {}, byBattleTag = {}, available = false }
  local numFriends = FriendScan.NumFriends(bnetApi)
  if numFriends == nil then
    return index
  end
  index.available = true
  for i = 1, numFriends do
    local okInfo, info = pcall(bnetApi.GetFriendAccountInfo, i)
    if okInfo and info then
      local entry = { accountInfo = info, friendIndex = i }
      local bnetAccountID = sanitizeAccountID(info.bnetAccountID)
      if bnetAccountID ~= nil and index.byAccountId[bnetAccountID] == nil then
        index.byAccountId[bnetAccountID] = entry
      end
      local battleTag = info.battleTag
      if battleTag ~= nil and index.byBattleTag[battleTag] == nil then
        index.byBattleTag[battleTag] = entry
      end
    end
  end
  return index
end

local function friendIndex(passCache, bnetApi)
  local index = passCache.index
  if index == nil then
    index = buildIndex(bnetApi, passCache.sanitizeAccountID)
    passCache.index = index
  end
  return index
end

-- The resolver writes what it learns for one contact (a probed game account,
-- GUID evidence) into the table it is handed. Two contacts can point at the
-- same friend, so each lookup gets its own copy of the indexed table.
local function copyOf(accountInfo)
  local copy = {}
  for key, value in pairs(accountInfo) do
    copy[key] = value
  end
  return copy
end

-- Returns accountInfo, friendIndex.
function PassCache.FindByAccountId(passCache, bnetApi, bnetAccountID)
  local entry = friendIndex(passCache, bnetApi).byAccountId[bnetAccountID]
  if entry == nil then
    return nil, nil
  end
  return copyOf(entry.accountInfo), entry.friendIndex
end

-- Returns accountInfo, friendIndex, listAvailable.
function PassCache.FindByBattleTag(passCache, bnetApi, battleTag)
  local index = friendIndex(passCache, bnetApi)
  local entry = battleTag ~= nil and index.byBattleTag[battleTag] or nil
  if entry == nil then
    return nil, nil, index.available
  end
  return copyOf(entry.accountInfo), entry.friendIndex, true
end

ns.BNetResolverPassCache = PassCache
return PassCache
