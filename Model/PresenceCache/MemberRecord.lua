local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Reads one guild/community member's fields into a PresenceCache scan
-- accumulator. Pure helpers: no module state, the caller passes the club API.
local MemberRecord = {}

function MemberRecord.PresenceToString(presence)
  if presence == 1 or presence == 2 or presence == 4 then
    return "online"
  end
  if presence == 3 then
    return "offline"
  end
  return nil
end

local function safeIpairs(tbl)
  local iterOk, iter, state, start = pcall(ipairs, tbl)
  if not iterOk then
    return ipairs({})
  end
  return iter, state, start
end

-- info.zone can be a secret value under 12.0 restricted content: the ~=
-- comparison itself can throw, so the whole validation (not just the field
-- read) must run under pcall in the caller.
function MemberRecord.ReadZone(info)
  local zone = info.zone
  if type(zone) == "string" and zone ~= "" then
    return zone
  end
  return nil
end

-- Same secret-value rule as ReadZone: run under pcall in the caller.
function MemberRecord.ReadLevel(info)
  local level = info.level
  if type(level) == "number" and level > 0 then
    return level
  end
  return nil
end

-- Reads info.presence inside the function, so a caller's pcall also covers
-- the field read itself, not just the conversion.
function MemberRecord.ReadPresence(info)
  return MemberRecord.PresenceToString(info.presence)
end

-- In 12.0 restricted content (e.g. Mythic+), info's fields can be "secret
-- values" — any ==/~= comparison or table-key use throws. Record one member
-- via pcall so a throw on this member (secret guid as table key, or secret
-- presence) skips it instead of aborting the whole club scan.
function MemberRecord.RecordMember(acc, clubId, memberId, info)
  acc.club[info.guid] = clubId
  acc.member[info.guid] = memberId
  -- Before the zone/level reads, so a secret zone or level can't drop it.
  if clubId ~= acc.guildClubId and acc.community[info.guid] == nil then
    acc.community[info.guid] = clubId
  end
  acc.freshAt[info.guid] = acc.now
  local p = MemberRecord.PresenceToString(info.presence)
  if p then
    acc.cache[info.guid] = p
  end
  -- RecordMember already runs under pcall (see CacheClub), so a throw from
  -- ReadZone on a secret zone just aborts this member like any other field.
  local zone = MemberRecord.ReadZone(info)
  if zone then
    acc.zoneByGuid[info.guid] = zone
  end
  -- Last, so a secret level can only lose the level, never presence or zone.
  local level = MemberRecord.ReadLevel(info)
  if level then
    acc.levelByGuid[info.guid] = level
  end
end

function MemberRecord.CacheClub(acc, api, clubId)
  local ok, members = pcall(api.GetClubMembers, clubId)
  if not ok or type(members) ~= "table" then
    return
  end
  for _, memberId in safeIpairs(members) do
    local infoOk, info = pcall(api.GetMemberInfo, clubId, memberId)
    if infoOk and info then
      pcall(MemberRecord.RecordMember, acc, clubId, memberId, info)
    end
  end
end

local function guildClubType()
  local enum = _G.Enum
  local clubTypes = type(enum) == "table" and enum.ClubType or nil
  return type(clubTypes) == "table" and clubTypes.Guild or nil
end

local function readClubType(club)
  return club.clubType
end

local function isGuildType(club)
  local guildType = guildClubType()
  if guildType == nil then
    return false
  end
  local ok, clubType = pcall(readClubType, club)
  return ok and clubType == guildType
end

-- GetSubscribedClubs lists the guild club too. It is skipped when
-- GetGuildClubId already cached it; when that call failed, the club type
-- still marks it as the guild, so guildmates are not indexed as community.
function MemberRecord.CacheSubscribedClub(acc, api, club)
  if club.clubId == acc.guildClubId then
    return
  end
  if acc.guildClubId == nil and isGuildType(club) then
    acc.guildClubId = club.clubId
  end
  MemberRecord.CacheClub(acc, api, club.clubId)
end

ns.PresenceCacheMemberRecord = MemberRecord

return MemberRecord
