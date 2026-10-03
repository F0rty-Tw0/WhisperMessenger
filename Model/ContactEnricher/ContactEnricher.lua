local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- stylua: ignore start
local AvailabilityEnricher = ns.AvailabilityEnricher or require("WhisperMessenger.Model.ContactEnricher.AvailabilityEnricher")
local Disambiguation = ns.ContactEnricherDisambiguation or require("WhisperMessenger.Model.ContactEnricher.Disambiguation")
local ConversationSnapshot = ns.ConversationSnapshot or require("WhisperMessenger.Model.ConversationSnapshot")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
-- stylua: ignore end

local ContactEnricher = {}

local PAUSED_WHISPER_HINT = "To reply now, type /w and their name in the game's chat."

-- While sending is paused our composer is locked, but the game's own chat
-- can still whisper, so whisper chats point there.
local function buildNotice(runtime, selectedContact, conversation)
  local notice = runtime.messagingNotice
  if notice == nil then
    return type(runtime.getGroupSendNotice) == "function" and runtime.getGroupSendNotice(conversation) or nil
  end
  local channel = selectedContact and selectedContact.channel
  if channel == "WOW" or channel == "BN" then
    return notice .. " " .. Localization.Text(PAUSED_WHISPER_HINT)
  end
  return notice
end

-- WoW whisper contacts only: Battle.net friends and groups aren't one
-- character on the block list.
local function isBlocked(runtime, contact)
  local filters = runtime.accountState and runtime.accountState.filters
  if contact.channel ~= "WOW" or type(filters) ~= "table" or type(filters.ignored) ~= "table" then
    return false
  end
  local now = type(runtime.now) == "function" and runtime.now() or nil
  -- Same name the contact menu's Block / Unblock uses.
  return IgnoreList.Lookup(filters, IgnoreList.CharacterName(contact.displayName, contact.guid), now) ~= nil
end

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

  -- WoW contacts: use cached availability from CAN_LOCAL_WHISPER_TARGET_RESPONSE
  if conversation and conversation.guid and runtime.availabilityByGUID[conversation.guid] then
    local cached = runtime.availabilityByGUID[conversation.guid]
    local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
    local isOpposite = AvailabilityEnricher.isOppositeFaction(conversation.factionName, runtime.localFaction)

    if isOpposite then
      if cached.status == "CanWhisper" then
        return Availability.FromStatus("XFaction")
      elseif cached.status == "WrongFaction" or cached.status == "Offline" then
        -- Build a minimal item for Disambiguation (only guid needed for presence lookup)
        return Disambiguation.ResolveWrongFaction({ guid = conversation.guid }, runtime, true)
      end
      return cached
    end

    if cached.status == "WrongFaction" then
      -- Build a minimal item for Disambiguation (guid + displayName for group-member check)
      return Disambiguation.ResolveWrongFaction({ guid = conversation.guid, displayName = conversation.displayName }, runtime, false)
    end
    return cached
  end

  return nil
end

-- Live presence flags read by the contact row preview and the header status
-- line: `isTyping` while the peer's typing indicator is inside its TTL and
-- `peerHasAddon` once any addon payload has arrived from them.
function ContactEnricher.EnrichContactsPresence(contacts, runtime)
  local LivePresence = ns.LivePresence or require("WhisperMessenger.Model.LivePresence")
  local now = type(runtime.now) == "function" and runtime.now() or 0
  for _, item in ipairs(contacts or {}) do
    item.isTyping = LivePresence.IsTyping(runtime, item.conversationKey, now)
    item.peerHasAddon = LivePresence.HasPeer(runtime, item.conversationKey)
  end
end

function ContactEnricher.BuildWindowSelectionState(runtime, contacts, buildContactsFn)
  local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
  local BNetStatus = ns.ContactEnricherBNetStatus or require("WhisperMessenger.Model.ContactEnricher.BNetStatus")
  local TableUtils = ns.TableUtils or require("WhisperMessenger.Util.TableUtils")
  if contacts == nil and buildContactsFn then
    contacts = buildContactsFn()
  end

  ContactEnricher.EnrichContactsAvailability(contacts, runtime)
  ContactEnricher.EnrichContactsPresence(contacts, runtime)

  if runtime.activeConversationKey == nil then
    return {
      contacts = contacts,
    }
  end

  local conversationKey = runtime.activeConversationKey
  local conversation = runtime.store.conversations[conversationKey]
  local selectedContact = TableUtils.findWhere(contacts, "conversationKey", conversationKey)
  if selectedContact == nil and conversation ~= nil then
    selectedContact = ConversationSnapshot.Build(conversationKey, conversation, runtime.accountState and runtime.accountState.settings)
    ContactEnricher.EnrichContactsPresence({ selectedContact }, runtime)
  end

  -- "New messages" divider captured when the conversation was opened.
  local divider = runtime.unreadDivider
  if selectedContact then
    selectedContact.unreadDividerMessage = divider and divider.conversationKey == conversationKey and divider.message or nil
    selectedContact.isBlocked = isBlocked(runtime, selectedContact)
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
      if BNetStatus.ApplyGameInfoMetadata(selectedContact, gameInfo, runtime) then
        selectedContact.characterName = gameInfo.characterName
        selectedContact.realm = gameInfo.realmName or gameInfo.realmDisplayName
      end
    end
  end

  return {
    contacts = contacts,
    selectedContact = selectedContact,
    conversation = conversation,
    status = selectedContact and selectedContact.availability or ContactEnricher.BuildConversationStatus(runtime, conversationKey, conversation),
    notice = buildNotice(runtime, selectedContact, conversation),
  }
end

ns.ContactEnricher = ContactEnricher
return ContactEnricher
