local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule

local ContactEnricher = {}

function ContactEnricher.EnrichContactsAvailability(contacts, runtime)
  local BNetResolver = loadModule("WhisperMessenger.Transport.BNetResolver", "BNetResolver")
  for _, item in ipairs(contacts) do
    -- WoW contacts: use cached availability from CAN_LOCAL_WHISPER_TARGET_RESPONSE
    if item.guid and runtime.availabilityByGUID[item.guid] then
      item.availability = runtime.availabilityByGUID[item.guid]
    end
    -- BNet contacts: query live status and refresh metadata from BNet API
    if item.channel == "BN" and item.bnetAccountID then
      local accountInfo = BNetResolver.ResolveAccountInfo(runtime.bnetApi, item.bnetAccountID, item.guid)
      if accountInfo then
        local gameInfo = accountInfo.gameAccountInfo
        if gameInfo and gameInfo.characterName then
          local Availability = loadModule("WhisperMessenger.Transport.Availability", "Availability")
          item.availability = Availability.FromStatus("CanWhisper")
          -- Refresh potentially stale metadata from live BNet data
          if gameInfo.factionName and gameInfo.factionName ~= "" then
            item.factionName = gameInfo.factionName
          end
          if gameInfo.className and gameInfo.className ~= "" then
            item.className = gameInfo.className
          end
          if gameInfo.raceName and gameInfo.raceName ~= "" then
            item.raceName = gameInfo.raceName
          end
        else
          local Availability = loadModule("WhisperMessenger.Transport.Availability", "Availability")
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
    local Availability = loadModule("WhisperMessenger.Transport.Availability", "Availability")
    return Availability.FromStatus("Lockdown")
  end

  if conversation and conversation.guid and runtime.availabilityByGUID[conversation.guid] then
    return runtime.availabilityByGUID[conversation.guid]
  end

  return nil
end

function ContactEnricher.BuildWindowSelectionState(runtime, contacts, buildContactsFn)
  local BNetResolver = loadModule("WhisperMessenger.Transport.BNetResolver", "BNetResolver")
  local TableUtils = loadModule("WhisperMessenger.Util.TableUtils", "TableUtils")

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
    local accountInfo = BNetResolver.ResolveAccountInfo(runtime.bnetApi, selectedContact.bnetAccountID, selectedContact.guid)
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
      end
    end
  end

  return {
    contacts = contacts,
    selectedContact = selectedContact,
    conversation = conversation,
    status = ContactEnricher.BuildConversationStatus(runtime, conversationKey, conversation),
  }
end

ns.ContactEnricher = ContactEnricher
return ContactEnricher
