local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Group chats that need no party: a named list of characters, kept
-- account-wide in accountState.groupChats by id. Members never include the
-- local character. A member on the player's own realm is kept as the bare
-- name ("Anna", or "Lone Gazer" in WoW: Forever, where names have two
-- words); one on another realm as "Name-Realm". Every client keeps its own
-- copy, synced over the group chat addon messages, which always carry the
-- realm (see Qualify).
local GroupChats = {}

GroupChats.MAX_MEMBERS = 10
GroupChats.MAX_NAME_CHARS = 32
GroupChats.ID_LENGTH = 8
GroupChats.KEY_PREFIX = "wmgroup::"

local ID_ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789"

local function trim(text)
  if type(text) ~= "string" then
    return nil
  end
  local trimmed = string.match(text, "^%s*(.-)%s*$")
  if trimmed == "" then
    return nil
  end
  return trimmed
end

local function lower(text)
  local ok, lowered = pcall(string.lower, text)
  return ok and lowered or nil
end

function GroupChats.Ensure(accountState)
  accountState.groupChats = accountState.groupChats or {}
  return accountState.groupChats
end

function GroupChats.IsValidId(id)
  return type(id) == "string" and #id == GroupChats.ID_LENGTH and string.match(id, "^[a-z0-9]+$") ~= nil
end

-- random(n) returns an integer in 1..n (math.random's contract).
function GroupChats.NewId(random)
  random = random or math.random
  local chars = {}
  for index = 1, GroupChats.ID_LENGTH do
    local pick = random(#ID_ALPHABET)
    chars[index] = string.sub(ID_ALPHABET, pick, pick)
  end
  return table.concat(chars)
end

function GroupChats.ConversationKey(id)
  return GroupChats.KEY_PREFIX .. id
end

function GroupChats.IdFromConversationKey(conversationKey)
  if type(conversationKey) ~= "string" or string.find(conversationKey, GroupChats.KEY_PREFIX, 1, true) ~= 1 then
    return nil
  end
  local id = string.sub(conversationKey, #GroupChats.KEY_PREFIX + 1)
  if not GroupChats.IsValidId(id) then
    return nil
  end
  return id
end

local function realmKey(realm)
  if type(realm) ~= "string" then
    return nil
  end
  local key = string.gsub(realm, "%s+", "")
  if key == "" then
    return nil
  end
  return key
end

-- A typed or received name as this client keeps it: spaces inside the name
-- kept (two-word names), the realm written without spaces and dropped when
-- it is the local one. nil for anything that cannot be a character name.
function GroupChats.FullName(name, localRealm)
  name = trim(name)
  if name == nil or string.find(name, "[,~|%c]") or string.find(name, "^%-") then
    return nil
  end
  local base, realm = string.match(name, "^([^%-]+)%-(.*)$")
  if base == nil then
    base = name
  end
  base = trim(string.gsub(base, "%s+", " "))
  if base == nil then
    return nil
  end
  if realm == nil then
    return base
  end
  realm = realmKey(realm)
  if realm == nil or string.find(realm, "-", 1, true) then
    return nil
  end
  local localKey = realmKey(localRealm)
  if localKey and lower(realm) == lower(localKey) then
    return base
  end
  return base .. "-" .. realm
end

-- The name with its realm, for the wire: a bare (same-realm) name gets the
-- local realm so a client on another realm reads it right.
function GroupChats.Qualify(name, localRealm)
  local localKey = realmKey(localRealm)
  if type(name) ~= "string" or localKey == nil or string.find(name, "-", 1, true) then
    return name
  end
  return name .. "-" .. localKey
end

function GroupChats.SameName(a, b)
  if type(a) ~= "string" or type(b) ~= "string" then
    return false
  end
  return lower(a) == lower(b)
end

local function containsName(list, name)
  for _, existing in ipairs(list) do
    if GroupChats.SameName(existing, name) then
      return true
    end
  end
  return false
end

-- Typed names, separated by commas or semicolons, as full names: duplicates
-- and the local character dropped, in the order typed.
function GroupChats.ParseNames(text, localRealm, selfName)
  local names = {}
  if type(text) ~= "string" then
    return names
  end
  for part in string.gmatch(text, "[^,;]+") do
    local fullName = GroupChats.FullName(part, localRealm)
    if fullName and not GroupChats.SameName(fullName, selfName) and not containsName(names, fullName) then
      names[#names + 1] = fullName
    end
  end
  return names
end

-- Group names travel inside addon messages: no separators or escapes.
function GroupChats.CleanName(name)
  name = trim(name)
  if name == nil then
    return nil
  end
  name = string.gsub(name, "[~|%c]", "")
  name = trim(name)
  if name == nil then
    return nil
  end
  local chars = 0
  for index = 1, #name do
    local byte = string.byte(name, index)
    if byte < 0x80 or byte >= 0xC0 then
      chars = chars + 1
      if chars > GroupChats.MAX_NAME_CHARS then
        return string.sub(name, 1, index - 1)
      end
    end
  end
  return name
end

function GroupChats.ShortName(fullName)
  if type(fullName) ~= "string" then
    return ""
  end
  return string.match(fullName, "^([^%-]+)") or fullName
end

-- "Anna, Bela, Csilla", the way a messenger names a group nobody named.
function GroupChats.DefaultName(members)
  local shortNames = {}
  for _, member in ipairs(members or {}) do
    shortNames[#shortNames + 1] = GroupChats.ShortName(member)
  end
  return GroupChats.CleanName(table.concat(shortNames, ", ")) or ""
end

function GroupChats.Find(registry, id)
  if type(registry) ~= "table" or id == nil then
    return nil
  end
  return registry[id]
end

function GroupChats.IsMember(group, name)
  return type(group) == "table" and type(group.members) == "table" and containsName(group.members, name)
end

-- Replaces the member list, keeping the first MAX_MEMBERS distinct names.
function GroupChats.SetMembers(group, names, selfName)
  local members = {}
  for _, name in ipairs(names or {}) do
    if #members >= GroupChats.MAX_MEMBERS then
      break
    end
    if type(name) == "string" and name ~= "" and not GroupChats.SameName(name, selfName) and not containsName(members, name) then
      members[#members + 1] = name
    end
  end
  group.members = members
  return members
end

-- Adds names not in the group yet while there is room; returns the added.
function GroupChats.AddMembers(group, names, selfName)
  local added = {}
  for _, name in ipairs(names or {}) do
    if #group.members >= GroupChats.MAX_MEMBERS then
      break
    end
    if type(name) == "string" and not GroupChats.SameName(name, selfName) and not containsName(group.members, name) then
      group.members[#group.members + 1] = name
      added[#added + 1] = name
    end
  end
  return added
end

function GroupChats.RemoveMember(group, name)
  for index, member in ipairs(group.members or {}) do
    if GroupChats.SameName(member, name) then
      table.remove(group.members, index)
      return true
    end
  end
  return false
end

-- spec: id, name, members, createdAt, selfName.
function GroupChats.Create(registry, spec)
  local group = {
    id = spec.id,
    name = GroupChats.CleanName(spec.name) or "",
    members = {},
    createdAt = spec.createdAt or 0,
  }
  GroupChats.SetMembers(group, spec.members, spec.selfName)
  if group.name == "" then
    group.name = GroupChats.DefaultName(group.members)
  end
  registry[group.id] = group
  return group
end

-- Groups the player still belongs to, oldest first.
function GroupChats.Joined(registry)
  local joined = {}
  for _, group in pairs(registry or {}) do
    if type(group) == "table" and group.left ~= true then
      joined[#joined + 1] = group
    end
  end
  table.sort(joined, function(a, b)
    if (a.createdAt or 0) ~= (b.createdAt or 0) then
      return (a.createdAt or 0) < (b.createdAt or 0)
    end
    return tostring(a.id) < tostring(b.id)
  end)
  return joined
end

-- "Anna, Bela-Kazzak": the members for a header line. Same-realm members
-- are already kept without their realm.
function GroupChats.MemberSummary(group)
  return table.concat(group and group.members or {}, ", ")
end

ns.GroupChats = GroupChats
return GroupChats
