local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContactEnricher = {}

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

function ContactEnricher.ShouldRequestAvailability(cached)
  if cached == nil then
    return true
  end
  -- Re-request for Offline (stale) and WrongFaction (player may have gone offline)
  return cached.status == "Offline" or cached.status == "WrongFaction"
end

function ContactEnricher.EnrichContactsAvailability(contacts, runtime)
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
        -- Same faction: WrongFaction is a stale or erroneous API response
        if item.availability.status == "WrongFaction" then
          item.availability = Availability.FromStatus("CanWhisper")
        end
      end
    end
    -- BNet contacts: query live status and refresh metadata from BNet API
    if item.channel == "BN" and item.bnetAccountID then
      local accountInfo = BNetResolver.ResolveAccountInfo(runtime.bnetApi, item.bnetAccountID, item.guid)
      if accountInfo then
        local gameInfo = accountInfo.gameAccountInfo
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
            -- Compute XFaction for BNet contacts in WoW with opposite faction
            if bnetStatus == "CanWhisper" and isOppositeFaction(item.factionName, localFaction) then
              item.availability = Availability.FromStatus("XFaction")
            end
          end
        else
          item.availability = Availability.FromStatus("Offline")
        end
      end
    end
  end
end

function ContactEnricher.BuildConversationStatus(runtime, conversationKey, conversation)
  if conversationKey == nil then
    return nil
  end

  if runtime.sendStatusByConversation[conversationKey] ~= nil then
    return runtime.sendStatusByConversation[conversationKey]
  end

  if runtime.isChatMessagingLocked and runtime.isChatMessagingLocked() then
    local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
    return Availability.FromStatus("Lockdown")
  end

  -- WoW contacts: use cached availability from CAN_LOCAL_WHISPER_TARGET_RESPONSE
  if conversation and conversation.guid and runtime.availabilityByGUID[conversation.guid] then
    return runtime.availabilityByGUID[conversation.guid]
  end

  return nil
end

function ContactEnricher.BuildWindowSelectionState(runtime, contacts, buildContactsFn)
  local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
  local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
  if contacts == nil and buildContactsFn then
    contacts = buildContactsFn(runtime)
  end

  ContactEnricher.EnrichContactsAvailability(contacts, runtime)

  if runtime.activeConversationKey == nil then
    return {
      contacts = contacts,
    }
  end

  local conversationKey = runtime.activeConversationKey
  local conversation = runtime.store.conversations[conversationKey]
  local selectedContact = TableUtils.findWhere(contacts, "conversationKey", conversationKey)
  if selectedContact == nil and conversation ~= nil then
    selectedContact = {
      conversationKey = conversationKey,
      displayName = conversation.displayName or conversation.contactDisplayName or conversationKey,
      lastPreview = conversation.lastPreview or "",
      unreadCount = conversation.unreadCount or 0,
      lastActivityAt = conversation.lastActivityAt or 0,
      channel = conversation.channel or "WOW",
      guid = conversation.guid,
      bnetAccountID = conversation.bnetAccountID,
      gameAccountName = conversation.gameAccountName,
      className = conversation.className,
      classTag = conversation.classTag,
      raceName = conversation.raceName,
      raceTag = conversation.raceTag,
      factionName = conversation.factionName,
    }
  end

  -- Enrich selected contact with live BNet metadata for display
  if selectedContact and selectedContact.channel == "BN" and selectedContact.bnetAccountID then
    local accountInfo =
      BNetResolver.ResolveAccountInfo(runtime.bnetApi, selectedContact.bnetAccountID, selectedContact.guid)
    if accountInfo then
      local gameInfo = accountInfo.gameAccountInfo
      if gameInfo then
        if gameInfo.factionName and gameInfo.factionName ~= "" then
          selectedContact.factionName = gameInfo.factionName
        end
        if gameInfo.className and gameInfo.className ~= "" then
          selectedContact.className = gameInfo.className
        end
        if gameInfo.raceName and gameInfo.raceName ~= "" then
          selectedContact.raceName = gameInfo.raceName
        end
        if gameInfo.characterName then
          selectedContact.characterName = gameInfo.characterName
          selectedContact.realm = gameInfo.realmName or gameInfo.realmDisplayName
        end
        -- Resolve classTag/raceTag from GUID (BNet API only provides localized className)
        local guid = gameInfo.playerGuid or selectedContact.guid
        if guid then
          enrichClassTag(selectedContact, guid, runtime)
        end
      end
    end
  end

  return {
    contacts = contacts,
    selectedContact = selectedContact,
    conversation = conversation,
    status = selectedContact and selectedContact.availability
      or ContactEnricher.BuildConversationStatus(runtime, conversationKey, conversation),
  }
end

ns.ContactEnricher = ContactEnricher
return ContactEnricher
