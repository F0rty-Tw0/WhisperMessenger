local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BNetStatus = {}

-- True only while the friend is logged into a WoW character. Offline friends
-- and Battle.net-app-only friends report no (or empty) characterName; any
-- className/areaName beside it is stale and must not be copied.
function BNetStatus.IsInWoW(gameInfo)
  return gameInfo ~= nil and type(gameInfo.characterName) == "string" and gameInfo.characterName ~= ""
end

-- Copy live character metadata from gameInfo onto target (a contact item or a
-- stored conversation). className and classTag are written together so the
-- class icon and the class text never describe different characters.
-- Returns true when metadata was applied (i.e. the friend is in WoW).
function BNetStatus.ApplyGameInfoMetadata(target, gameInfo, runtime)
  if not BNetStatus.IsInWoW(gameInfo) then
    return false
  end
  if gameInfo.factionName and gameInfo.factionName ~= "" then
    target.factionName = gameInfo.factionName
  end
  if gameInfo.raceName and gameInfo.raceName ~= "" then
    target.raceName = gameInfo.raceName
  end
  if gameInfo.areaName and gameInfo.areaName ~= "" then
    target.areaName = gameInfo.areaName
  end
  local guid = gameInfo.playerGuid or target.guid
  local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
  local playerInfo = guid and BNetResolver.ResolvePlayerInfo(runtime.playerInfoByGUID, guid)
  if playerInfo and playerInfo.classTag then
    target.classTag = playerInfo.classTag
    target.className = (gameInfo.className ~= nil and gameInfo.className ~= "") and gameInfo.className or playerInfo.className or target.className
    if playerInfo.raceTag then
      target.raceTag = playerInfo.raceTag
    end
  end
  -- else: classTag unresolvable — leave BOTH className and classTag untouched
  -- (stale but consistent beats a mismatched icon/text pair)
  return true
end

-- Apply live BNet status and refresh metadata from the BNet API for a BNet contact.
-- Handles ResolveAccountInfo, isOnline/isAFK/isDND/isGameAFK sticky-flag logic,
-- metadata refresh from gameAccountInfo, and presence-cache fallback when
-- accountInfo is nil.
-- Called when: item.channel == "BN" and item.bnetAccountID is set.
function BNetStatus.Apply(item, runtime)
  local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
  local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
  local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")

  local accountInfo = BNetResolver.ResolveAccountInfo(runtime.bnetApi, item.bnetAccountID, item.guid, item.battleTag or item.displayName)
  if accountInfo then
    if accountInfo.bnetAccountID then
      item.bnetAccountID = accountInfo.bnetAccountID
      if runtime.store and runtime.store.conversations and item.conversationKey then
        local conversation = runtime.store.conversations[item.conversationKey]
        if conversation then
          conversation.bnetAccountID = item.bnetAccountID
        end
      end
    end
    local gameInfo = accountInfo.gameAccountInfo
    -- isAFK/isDND are STICKY on BNetAccountInfo — they persist after a friend
    -- goes offline. Only isOnline (strict true) or game-account presence prove
    -- they are actually connected; sticky flags are valid only as sub-status.
    local isOnline = accountInfo.isOnline == true or (gameInfo and (gameInfo.isOnline or gameInfo.characterName))
    if isOnline then
      -- Check AFK/DND first (applies whether in WoW or BNet app)
      local inWoW = gameInfo and (gameInfo.isOnline or gameInfo.characterName)
      local bnetStatus
      if accountInfo.isAFK or (gameInfo and gameInfo.isGameAFK) then
        bnetStatus = "Away"
      elseif accountInfo.isDND or (gameInfo and gameInfo.isGameBusy) then
        bnetStatus = "Busy"
      elseif not inWoW then
        -- Online in BNet app or another Blizzard game, not in WoW
        bnetStatus = "BNetOnline"
      else
        bnetStatus = "CanWhisper"
      end
      item.availability = Availability.FromStatus(bnetStatus)
      -- Refresh potentially stale metadata from live BNet data, but only
      -- while the friend is actually in WoW — otherwise leave it as-is.
      BNetStatus.ApplyGameInfoMetadata(item, gameInfo, runtime)
    elseif accountInfo.isOnline == false then
      -- BNet API explicitly says offline at account level; fall back to guild/community presence
      local presence = item.guid and PresenceCache.GetPresence(item.guid) or nil
      if presence == "online" then
        -- BNet whispers are always cross-faction; no XFaction needed
        item.availability = Availability.FromStatus("CanWhisper")
      else
        item.availability = Availability.FromStatus("Offline")
      end
    elseif accountInfo.isOnline == nil then
      -- isOnline is nil (unknown at account level). Could be BNet mobile app user
      -- or API still loading. Check guild/community presence for ground truth.
      local presence = item.guid and PresenceCache.GetPresence(item.guid) or nil
      if presence == "online" then
        -- Guild/community says online — they're in WoW, BNet API just hasn't caught up
        item.availability = Availability.FromStatus("CanWhisper")
      elseif presence == "offline" then
        -- Guild/community explicitly offline — trust the positive signal over the
        -- ambiguous BNet state; don't fall back to "probably mobile" BNetOnline.
        item.availability = Availability.FromStatus("Offline")
      else
        -- No presence cache entry — no way to disambiguate; likely BNet mobile app.
        item.availability = Availability.FromStatus("BNetOnline")
      end
    end
  end
  -- BNet contact without resolvable accountInfo (API has no data for this friend):
  -- trust guild/community presence if we have it, otherwise default to Offline so
  -- the status bar always shows a concrete state instead of leaking stale data.
  if item.availability == nil then
    local presence = item.guid and PresenceCache.GetPresence(item.guid) or nil
    if presence == "online" then
      item.availability = Availability.FromStatus("CanWhisper")
    else
      item.availability = Availability.FromStatus("Offline")
    end
  end
end

ns.ContactEnricherBNetStatus = BNetStatus
return BNetStatus
