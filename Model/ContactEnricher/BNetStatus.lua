local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BNetStatus = {}

-- Resolve classTag/raceTag for a contact via GetPlayerInfoByGUID.
-- The BNet API provides className (localized) but not classTag (engine token),
-- which is needed for class coloring and icons.
local function enrichClassTag(item, guid, runtime)
  local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
  local playerInfo = BNetResolver.ResolvePlayerInfo(runtime.playerInfoByGUID, guid)
  if playerInfo then
    if playerInfo.classTag then
      item.classTag = playerInfo.classTag
    end
    if playerInfo.raceTag then
      item.raceTag = playerInfo.raceTag
    end
  end
end

-- Expose for re-export on AvailabilityEnricher facade (ContactEnricher.lua uses it)
BNetStatus.EnrichClassTag = enrichClassTag

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
      -- Refresh potentially stale metadata from live BNet data when in WoW
      if gameInfo and gameInfo.characterName then
        if gameInfo.factionName and gameInfo.factionName ~= "" then
          item.factionName = gameInfo.factionName
        end
        if gameInfo.className and gameInfo.className ~= "" then
          item.className = gameInfo.className
        end
        if gameInfo.raceName and gameInfo.raceName ~= "" then
          item.raceName = gameInfo.raceName
        end
        -- Resolve classTag/raceTag from GUID (BNet API only provides localized className)
        local guid = gameInfo.playerGuid or item.guid
        if guid then
          enrichClassTag(item, guid, runtime)
        end
        -- BNet whispers are always cross-faction; no XFaction status needed
      end
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
