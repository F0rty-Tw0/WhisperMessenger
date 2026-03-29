local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AvailabilityEnricher = ns.AvailabilityEnricher
  or require("WhisperMessenger.Model.ContactEnricher.AvailabilityEnricher")
local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")
local ConversationSnapshot = ns.ConversationSnapshot or require("WhisperMessenger.Model.ConversationSnapshot")

local ContactEnricher = {}

-- Re-export availability functions for backward compatibility
ContactEnricher.ShouldRequestAvailability = AvailabilityEnricher.ShouldRequestAvailability
ContactEnricher.EnrichContactsAvailability = AvailabilityEnricher.EnrichContactsAvailability

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
    local cached = runtime.availabilityByGUID[conversation.guid]
    if cached.status == "WrongFaction" then
      local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
      if AvailabilityEnricher.isOppositeFaction(conversation.factionName, runtime.localFaction) then
        -- Opposite faction: check guild/community presence
        local presence = PresenceCache.GetPresence(conversation.guid)
        if presence == "online" then
          return Availability.FromStatus("XFaction")
        end
        return cached
      else
        -- Same faction or unknown: WrongFaction means offline unless guild/community says online
        local presence = PresenceCache.GetPresence(conversation.guid)
        if presence == "online" then
          return Availability.FromStatus("CanWhisper")
        end
        return Availability.FromStatus("Offline")
      end
    end
    return cached
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
    selectedContact = ConversationSnapshot.Build(conversationKey, conversation)
  end

  -- Enrich selected contact with live BNet metadata for display
  if selectedContact and selectedContact.channel == "BN" and selectedContact.bnetAccountID then
    local accountInfo = BNetResolver.ResolveAccountInfo(
      runtime.bnetApi,
      selectedContact.bnetAccountID,
      selectedContact.guid,
      selectedContact.battleTag or selectedContact.displayName
    )
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
          AvailabilityEnricher.enrichClassTag(selectedContact, guid, runtime)
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
