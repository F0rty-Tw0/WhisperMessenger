local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")

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

-- Check if a GUID matches any BNet friend's game account.
-- Returns the BNet accountInfo if found and online, nil otherwise.
local function findBNetFriendByGUID(guid, bnetApi)
  if guid == nil or type(bnetApi) ~= "table" then
    return nil
  end
  if type(bnetApi.GetAccountInfoByGUID) == "function" then
    local ok, info = pcall(bnetApi.GetAccountInfoByGUID, guid)
    if ok and info and (info.isOnline or info.isAFK or info.isDND) then
      return info
    end
  end
  return nil
end

-- Check if a player name is in our party/raid and connected.
-- Uses UnitIsConnected with group unit tokens.
local function isGroupMemberOnline(displayName)
  if displayName == nil then
    return false
  end
  local UnitIsConnected = _G.UnitIsConnected
  local UnitName = _G.UnitName
  local GetNumGroupMembers = _G.GetNumGroupMembers
  if type(UnitIsConnected) ~= "function" or type(UnitName) ~= "function" then
    return false
  end
  local numMembers = type(GetNumGroupMembers) == "function" and GetNumGroupMembers() or 0
  if numMembers == 0 then
    return false
  end
  -- Normalize: compare lowercase name before realm separator
  local targetName = string.lower(string.match(displayName, "^([^%-]+)") or displayName)
  local IsInRaid = _G.IsInRaid
  local prefix = (type(IsInRaid) == "function" and IsInRaid()) and "raid" or "party"
  for i = 1, numMembers do
    local unit = prefix .. i
    local name = UnitName(unit)
    if name and string.lower(name) == targetName then
      return UnitIsConnected(unit) == true
    end
  end
  return false
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
      -- Infer and persist faction from CanWhisper status when faction is unknown.
      -- CanWhisper for a WoW contact strongly implies same faction as local player.
      -- NOTE: WrongFaction is NOT reliable for faction inference — it's a generic
      -- "unreachable" status that fires for same-faction cross-realm players too.
      -- Faction doesn't change per character, so we persist it once inferred.
      if
        item.factionName == nil
        and localFaction
        and item.channel ~= "BN"
        and item.availability.status == "CanWhisper"
      then
        item.factionName = localFaction
        -- Persist to conversation so we don't lose it across refreshes
        if runtime.store and item.conversationKey then
          local conversation = runtime.store.conversations[item.conversationKey]
          if conversation and conversation.factionName == nil then
            conversation.factionName = item.factionName
          end
        end
      end
      if isOppositeFaction(item.factionName, localFaction) then
        if item.availability.status == "CanWhisper" then
          -- CanWhisper + opposite faction = cross-faction guild/community member
          item.availability = Availability.FromStatus("XFaction")
        elseif item.availability.status == "WrongFaction" or item.availability.status == "Offline" then
          -- API returns WrongFaction for all opposite-faction players;
          -- Offline may be stale — check guild/community presence to distinguish
          local presence = PresenceCache.GetPresence(item.guid)
          if presence == "online" then
            item.availability = Availability.FromStatus("XFaction")
          elseif presence == "offline" then
            item.availability = Availability.FromStatus("Offline")
          end
          -- nil = not a member, keep original status
        end
      else
        -- Same faction or unknown faction: WrongFaction (code 2) is ambiguous —
        -- it fires for both offline players AND online cross-realm unreachable players.
        -- Check multiple sources to determine actual status.
        if item.availability.status == "WrongFaction" then
          local resolved = false
          -- 1. Guild/community presence cache
          local presence = PresenceCache.GetPresence(item.guid)
          if presence == "online" then
            item.availability = Availability.FromStatus("CanWhisper")
            resolved = true
          elseif presence == "offline" then
            item.availability = Availability.FromStatus("Offline")
            resolved = true
          end
          -- 2. BNet friend check (covers cross-realm BNet friends)
          if not resolved then
            local bnetInfo = findBNetFriendByGUID(item.guid, runtime.bnetApi)
            if bnetInfo then
              local bnetStatus = "CanWhisper"
              if bnetInfo.isAFK then
                bnetStatus = "Away"
              elseif bnetInfo.isDND then
                bnetStatus = "Busy"
              end
              item.availability = Availability.FromStatus(bnetStatus)
              resolved = true
            end
          end
          -- 3. Party/raid member check
          if not resolved and isGroupMemberOnline(item.displayName or item.playerName) then
            item.availability = Availability.FromStatus("CanWhisper")
            resolved = true
          end
          -- 4. Fallback: Unavailable (we can't determine if online or offline)
          if not resolved then
            item.availability = Availability.FromStatus("Unavailable")
          end
        end
      end
    elseif item.guid and item.channel ~= "BN" then
      -- No cached availability yet; use guild/community presence as initial status
      local presence = PresenceCache.GetPresence(item.guid)
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
        elseif accountInfo.isOnline == false or (gameInfo and gameInfo.isOnline == false) then
          -- BNet API explicitly says offline; fall back to guild/community presence
          local presence = item.guid and PresenceCache.GetPresence(item.guid) or nil
          if presence == "online" then
            -- BNet whispers are always cross-faction; no XFaction needed
            item.availability = Availability.FromStatus("CanWhisper")
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
