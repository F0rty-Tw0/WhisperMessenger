local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Sends a character's whispers to the Battle.net chat of the friend who owns
-- that character. The map decides first; the Battle.net lookup runs only for
-- a character that is neither merged nor separated.
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
local CharacterMergeMap = ns.CharacterMergeMap or require("WhisperMessenger.Model.CharacterMergeMap")
local CharacterMergeFold = ns.CharacterMergeFold or require("WhisperMessenger.Model.CharacterMergeFold")

local CharacterRedirect = {}

local function maxMessagesOf(store)
  return store.config and store.config.maxMessagesPerConversation
end

-- Every fold tells the runtime before the line is stored, so state that
-- follows the chat (the open chat above all) moves to the friend's chat first.
-- The third result says the fold opened the friend's chat with nothing in
-- it, so the line about to be stored opens a new chat.
local function fold(state, characterKey, bnetKey, bnetContact, name)
  local store = state.store
  local opensNewChat = store.conversations[bnetKey] == nil and store.conversations[characterKey] == nil
  CharacterMergeFold.Fold(store, state.characterMerges, characterKey, bnetKey, bnetContact, name, maxMessagesOf(store))
  if type(state.onCharacterMerged) == "function" then
    state.onCharacterMerged(characterKey, bnetKey)
  end
  return bnetKey, CharacterMergeMap.Get(state.characterMerges, characterKey), opensNewChat
end

local function cacheMiss(state, characterKey)
  state.characterMergeMisses = state.characterMergeMisses or {}
  state.characterMergeMisses[characterKey] = true
end

-- A GUID the client hides or leaves blank is never passed on, and no miss is
-- cached: a later event that carries a readable GUID may still match.
local function readableGuid(payload, contact)
  local guid = payload and payload.guid
  if guid == nil then
    guid = contact.guid
  end
  if SecretValue.Is(guid) or type(guid) ~= "string" or guid == "" then
    return nil
  end

  return guid
end

-- The friend who owns the character, as a contact, or nil. Only the account
-- id and battle tag are taken from the API answer, both checked for secrets
-- before any other test on them. An answer that says the account is not a
-- friend (or hides whether it is) is no match; one without the flag is.
local function lookupFriend(state, guid)
  local api = state.bnetApi
  if type(api) ~= "table" or type(api.GetAccountInfoByGUID) ~= "function" then
    return nil, false
  end
  local ok, info = pcall(api.GetAccountInfoByGUID, guid)
  if not ok or SecretValue.Is(info) or type(info) ~= "table" then
    return nil, true
  end
  if SecretValue.Is(info.isFriend) or info.isFriend == false then
    return nil, true
  end
  local battleTag = info.battleTag
  if SecretValue.Is(battleTag) or type(battleTag) ~= "string" or battleTag == "" then
    return nil, true
  end
  local accountID = info.bnetAccountID
  if SecretValue.Is(accountID) then
    accountID = nil
  end
  return Identity.FromBattleNet(accountID, { battleTag = battleTag }), true
end

local function resolveUnmerged(state, contact, characterKey, payload)
  local misses = state.characterMergeMisses
  if misses and misses[characterKey] then
    return characterKey, nil
  end
  local guid = readableGuid(payload, contact)
  if guid == nil or SecretValue.Is(contact.displayName) then
    return characterKey, nil
  end
  local bnetContact, asked = lookupFriend(state, guid)
  if bnetContact == nil then
    if asked then
      cacheMiss(state, characterKey)
    end
    return characterKey, nil
  end
  local bnetKey = Identity.BuildConversationKey(state.localProfileId, bnetContact.contactKey)
  local characterChat = state.store.conversations[characterKey]
  local name = (characterChat and characterChat.displayName) or contact.displayName
  return fold(state, characterKey, bnetKey, bnetContact, name)
end

function CharacterRedirect.Resolve(state, contact, characterKey, payload)
  local merges = state.characterMerges
  local store = state.store
  if contact == nil or contact.channel ~= "WOW" or merges == nil or store == nil then
    return characterKey, nil
  end
  if CharacterMergeMap.IsSeparated(merges, characterKey) then
    return characterKey, nil
  end
  local entry = CharacterMergeMap.Get(merges, characterKey)
  -- The only place a stale entry is dropped; every other lookup only reads.
  if entry ~= nil and store.conversations[entry.bnetKey] == nil then
    CharacterMergeMap.Drop(merges, characterKey)
    entry = nil
  end
  if entry == nil then
    return resolveUnmerged(state, contact, characterKey, payload)
  end
  if store.conversations[characterKey] ~= nil then
    return fold(state, characterKey, entry.bnetKey, nil, entry.name)
  end

  return entry.bnetKey, entry
end

-- Resolve returns an entry only for a character whisper, so the line already
-- carries the WOW channel that marks it as a character line inside B.
function CharacterRedirect.Stamp(message, entry)
  if entry == nil then
    return
  end
  message.playerName = entry.name
end

ns.EventRouterCharacterRedirect = CharacterRedirect
return CharacterRedirect
