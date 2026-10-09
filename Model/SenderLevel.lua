local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")
local SeenLevel = ns.SeenLevel or require("WhisperMessenger.Model.SeenLevel")

local SenderLevel = {}

-- Every check runs inside the pcalled step: comparing a 12.0 secret value
-- throws, which fails the step instead of escaping to the chat handler.
local function validLevel(value)
  if type(value) == "number" and value > 0 then
    return value
  end
  return nil
end

-- Flavors without UnitTokenFromGUID: walk the roster comparing GUIDs.
local function scanGroup(guid)
  local count = _G.GetNumGroupMembers()
  local prefix, last = "party", count - 1
  if _G.IsInRaid() then
    prefix, last = "raid", count
  end
  for i = 1, last do
    local unit = prefix .. i
    if _G.UnitGUID(unit) == guid then
      return unit
    end
  end
  return nil
end

-- Any live unit token counts (party, raid, target, mouseover, nameplate):
-- the game already shows that unit's level to the player.
local function unitLevel(guid)
  local unit
  if _G.UnitTokenFromGUID then
    unit = _G.UnitTokenFromGUID(guid)
  else
    unit = scanGroup(guid)
  end
  if unit == nil then
    return nil
  end
  return validLevel(_G.UnitLevel(unit))
end

local function clubLevel(guid)
  return validLevel(PresenceCache.ReadLevel(guid))
end

-- A multi-account friend's game account may be another character, so the
-- level counts only when it belongs to this GUID.
local function bnetLevel(guid)
  local account = _G.C_BattleNet.GetAccountInfoByGUID(guid)
  local game = account and account.gameAccountInfo
  if game == nil or game.playerGuid ~= guid then
    return nil
  end
  return validLevel(game.characterLevel)
end

-- Last resort: a level the game showed earlier this session.
local function seenLevel(guid, name)
  return validLevel(SeenLevel.Get(guid, name))
end

local STEPS = { unitLevel, clubLevel, bnetLevel, seenLevel }

function SenderLevel.Lookup(guid, name)
  if guid == nil then
    return nil
  end
  for _, step in ipairs(STEPS) do
    local ok, level = pcall(step, guid, name)
    if ok and level then
      return level
    end
  end
  return nil
end

ns.SenderLevel = SenderLevel

return SenderLevel
