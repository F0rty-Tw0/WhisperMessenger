local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationOps = {}

function ConversationOps.findConversationKeyByName(runtime, name)
  if not name or not runtime.store or not runtime.store.conversations then
    return nil
  end

  local lowerName = string.lower(name)
  local inputBase = string.match(name, "^([^%-]+)")
  for key, conv in pairs(runtime.store.conversations) do
    local displayName = conv.displayName or conv.contactDisplayName or ""
    if string.lower(displayName) == lowerName then
      return key
    end

    local baseName = string.match(displayName, "^([^%-]+)")
    if baseName and string.lower(baseName) == lowerName then
      return key
    end

    if inputBase and string.lower(displayName) == string.lower(inputBase) then
      return key
    end

    if conv.battleTag and string.lower(conv.battleTag) == lowerName then
      return key
    end

    if conv.gameAccountName and string.lower(conv.gameAccountName) == lowerName then
      return key
    end
  end

  return nil
end

function ConversationOps.buildConversationKeyFromName(runtime, identity, name)
  local contact = identity.FromWhisper(name, nil, {})
  if contact.canonicalName == "" then
    return nil
  end

  return identity.BuildConversationKey(runtime.localProfileId, contact.contactKey)
end

function ConversationOps.ensureConversation(runtime, conversationKey, displayName)
  if not runtime.store then
    runtime.store = {}
  end
  runtime.store.conversations = runtime.store.conversations or {}

  if runtime.store.conversations[conversationKey] then
    return
  end

  runtime.store.conversations[conversationKey] = {
    displayName = displayName,
    channel = "WOW",
    messages = {},
    unreadCount = 0,
    lastActivityAt = runtime.now(),
    conversationKey = conversationKey,
  }
end

function ConversationOps.ensureBattleNetConversation(runtime, identity, accountInfo)
  local bnetAccountID = accountInfo and accountInfo.bnetAccountID
  if not bnetAccountID then
    return nil
  end

  if not runtime.store then
    runtime.store = {}
  end
  runtime.store.conversations = runtime.store.conversations or {}
  local conversations = runtime.store.conversations
  for key, conversation in pairs(conversations) do
    if conversation.bnetAccountID == bnetAccountID then
      return key
    end
  end

  local contact = identity.FromBattleNet(bnetAccountID, accountInfo)
  if contact.canonicalName == "" then
    return nil
  end

  local conversationKey = identity.BuildConversationKey(runtime.localProfileId, contact.contactKey)
  conversations[conversationKey] = {
    displayName = accountInfo.battleTag or accountInfo.accountName or tostring(bnetAccountID),
    channel = "BN",
    bnetAccountID = bnetAccountID,
    battleTag = accountInfo.battleTag,
    gameAccountName = accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.characterName,
    messages = {},
    unreadCount = 0,
    lastActivityAt = runtime.now(),
    conversationKey = conversationKey,
  }

  return conversationKey
end

ns.BootstrapAutoOpenConversationOps = ConversationOps

return ConversationOps
