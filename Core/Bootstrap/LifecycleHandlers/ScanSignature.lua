local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- Did a BN scan change what an open window shows for a friend? The status
-- dot, the away / busy text and the header's character line are worked out
-- from live friend data on every refresh and never stored on the
-- conversation, so ScanFieldDiff cannot see them change. This keeps the last
-- scanned value of every live field the window reads, per conversation key,
-- for the session only.
local ScanSignature = {}

-- Read by ContactEnricher.BNetStatus (online, away, busy, last online).
local ACCOUNT_FIELDS = { "isOnline", "isAFK", "isDND", "lastOnlineTime" }

-- Read by ContactEnricher.BNetStatus, the selected contact's header and
-- Relationship: presence, the character, its class, race, level, zone,
-- faction and realm.
local GAME_FIELDS = {
  "isOnline",
  "isGameAFK",
  "isGameBusy",
  "clientProgram",
  "characterName",
  "realmName",
  "realmDisplayName",
  "className",
  "raceName",
  "characterLevel",
  "areaName",
  "factionName",
  "playerGuid",
}

local GAME_OFFSET = #ACCOUNT_FIELDS

-- Classic flavors may leave out gameAccountInfo: every game field then
-- reads as nil.
local EMPTY = {}

-- Stands in for any secret value: comparing one raises, and each read hands
-- out a new one, so secrets are only told apart from readable values.
local SECRET = {}

-- One signature is a table with a fixed slot per field (nil holes allowed),
-- updated in place so a scan that changes nothing allocates nothing.
local function storeFields(signature, offset, fields, source)
  local changed = false
  for index, field in ipairs(fields) do
    local value = source[field]
    if SecretValue.Is(value) then
      value = SECRET
    end
    if signature[offset + index] ~= value then
      signature[offset + index] = value
      changed = true
    end
  end
  return changed
end

-- accountInfo: what BNetResolver.ResolveAccountInfo answers for the
-- conversation, which is the account the open window draws (the resolver
-- may pick another game account than the friend list's primary one), or nil
-- when the friend no longer resolves (removed from the list).
-- Returns true when the friend's live state differs from the last scan; a
-- friend seen for the first time counts as changed.
function ScanSignature.Update(signatures, key, accountInfo)
  local signature = signatures[key]
  if type(accountInfo) ~= "table" then
    signatures[key] = nil
    return signature ~= nil
  end

  local changed = signature == nil
  if signature == nil then
    signature = {}
    signatures[key] = signature
  end
  local gameInfo = type(accountInfo.gameAccountInfo) == "table" and accountInfo.gameAccountInfo or EMPTY
  if storeFields(signature, 0, ACCOUNT_FIELDS, accountInfo) then
    changed = true
  end
  if storeFields(signature, GAME_OFFSET, GAME_FIELDS, gameInfo) then
    changed = true
  end
  return changed
end

-- Drops the signatures of conversations that are gone: deleted, or moved to
-- another key by a rekey.
function ScanSignature.Prune(signatures, conversations)
  for key in pairs(signatures) do
    if conversations[key] == nil then
      signatures[key] = nil
    end
  end
end

ns.BootstrapLifecycleHandlersScanSignature = ScanSignature
return ScanSignature
