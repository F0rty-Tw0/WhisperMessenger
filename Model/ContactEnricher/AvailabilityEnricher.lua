local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AvailabilityEnricher = {}

-- Check if contact is opposite faction from local player.
-- Returns true only when both factions are known and differ.
local function isOppositeFaction(itemFaction, localFaction)
  if localFaction == nil or itemFaction == nil or itemFaction == "" then
    return false
  end
  return itemFaction ~= localFaction
end

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

-- Expose helpers for use by ContactEnricher facade
AvailabilityEnricher.isOppositeFaction = isOppositeFaction
AvailabilityEnricher.enrichClassTag = enrichClassTag

function AvailabilityEnricher.ShouldRequestAvailability(_cached)
  -- Always re-request: the async whisper-check API is lightweight and ensures
  -- statuses stay fresh. A player marked CanWhisper may have gone offline,
  -- and a WrongFaction player may have come online. Re-checking every refresh
  -- cycle keeps the UI accurate without manual intervention.
  return true
end

function AvailabilityEnricher.EnrichContactsAvailability(contacts, runtime)
  local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
  local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
  local localFaction = runtime.localFaction
  for _, item in ipairs(contacts) do
    -- WoW contacts: use cached availability from CAN_LOCAL_WHISPER_TARGET_RESPONSE
    if item.guid and runtime.availabilityByGUID[item.guid] then
      item.availability = runtime.availabilityByGUID[item.guid]
      if isOppositeFaction(item.factionName, localFaction) then
        if item.availability.status == "CanWhisper" then
          -- CanWhisper + opposite faction = cross-faction guild/community member
          item.availability = Availability.FromStatus("XFaction")
        elseif
          (item.availability.status == "WrongFaction" or item.availability.status == "Offline")
          and type(runtime.getGuildOrCommunityPresence) == "function"
        then
          -- API returns WrongFaction for all opposite-faction players;
          -- Offline may be stale — check guild/community presence to distinguish
          local presence = runtime.getGuildOrCommunityPresence(item.guid)
          if presence == "online" then
            item.availability = Availability.FromStatus("XFaction")
          elseif presence == "offline" then
            item.availability = Availability.FromStatus("Offline")
          end
          -- nil = not a member, keep original status
        end
      else
        -- Same faction or unknown faction: WrongFaction likely means the player
        -- is offline (the API returns code 2 for unreachable players regardless
        -- of faction). Check guild/community presence, default to Offline.
        if item.availability.status == "WrongFaction" then
          if type(runtime.getGuildOrCommunityPresence) == "function" then
            local presence = runtime.getGuildOrCommunityPresence(item.guid)
            if presence == "online" then
              item.availability = Availability.FromStatus("CanWhisper")
            else
              item.availability = Availability.FromStatus("Offline")
            end
          else
            item.availability = Availability.FromStatus("Offline")
          end
        end
      end
    elseif item.guid and item.channel ~= "BN" and type(runtime.getGuildOrCommunityPresence) == "function" then
      -- No cached availability yet; use guild/community presence as initial status
      local presence = runtime.getGuildOrCommunityPresence(item.guid)
      if presence == "online" then
        if isOppositeFaction(item.factionName, localFaction) then
          item.availability = Availability.FromStatus("XFaction")
        else
          item.availability = Availability.FromStatus("CanWhisper")
        end
      elseif presence == "offline" then
        item.availability = Availability.FromStatus("Offline")
      end
    end
    -- WoW contacts with no availability after all checks: default to Offline
    if item.availability == nil and item.channel ~= "BN" then
      item.availability = Availability.FromStatus("Offline")
    end
    -- BNet contacts: query live status and refresh metadata from BNet API
    if item.channel == "BN" and item.bnetAccountID then
      local accountInfo = BNetResolver.ResolveAccountInfo(
        runtime.bnetApi,
        item.bnetAccountID,
        item.guid,
        item.battleTag or item.displayName
      )
      if accountInfo then
        local gameInfo = accountInfo.gameAccountInfo
        -- isAFK/isDND at account level imply online (you can't be AFK if not logged in)
        local isOnline = accountInfo.isOnline
          or accountInfo.isAFK
          or accountInfo.isDND
          or (gameInfo and (gameInfo.isOnline or gameInfo.characterName))
        if isOnline then
          local bnetStatus = "CanWhisper"
          -- Check both top-level (BNet app) and game-level AFK/DND flags
          if accountInfo.isAFK or (gameInfo and gameInfo.isGameAFK) then
            bnetStatus = "Away"
          elseif accountInfo.isDND or (gameInfo and gameInfo.isGameBusy) then
            bnetStatus = "Busy"
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
        elseif accountInfo.isOnline == false or (gameInfo and gameInfo.isOnline == false) then
          -- BNet API explicitly says offline; fall back to guild/community presence
          if item.guid and type(runtime.getGuildOrCommunityPresence) == "function" then
            local presence = runtime.getGuildOrCommunityPresence(item.guid)
            if presence == "online" then
              -- BNet whispers are always cross-faction; no XFaction needed
              item.availability = Availability.FromStatus("CanWhisper")
            else
              item.availability = Availability.FromStatus("Offline")
            end
          else
            item.availability = Availability.FromStatus("Offline")
          end
        end
        -- When isOnline is nil (unknown), skip — don't override to Offline.
        -- The API may not have loaded yet, or the friend is on the desktop app.
      end
    end
  end
end

ns.AvailabilityEnricher = AvailabilityEnricher
return AvailabilityEnricher
