local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local ConversationOps = {}

function ConversationOps.findConversationKeyByName(runtime, name)
  return Identity.ResolveWhisperConversation(runtime, name, "WOW")
end

function ConversationOps.buildConversationKeyFromName(runtime, identity, name)
  local contact = identity.FromWhisper(name, nil, {})
  if contact.canonicalName == "" then
    return nil
  end

  return identity.BuildConversationKey(runtime.localProfileId, contact.contactKey)
end

function ConversationOps.ensureConversation(runtime, conversationKey, displayName)
  runtime.store = runtime.store or {}
  local now = type(runtime.now) == "function" and runtime.now() or 0
  return Store.EnsureConversation(runtime.store, conversationKey, {
    channel = "WOW",
    displayName = displayName,
    lastActivityAt = now,
  })
end

function ConversationOps.ensureBattleNetConversation(runtime, identity, accountInfo)
  local bnetAccountID = accountInfo and accountInfo.bnetAccountID
  if not bnetAccountID then
    return nil
  end
  local existingKey = Identity.ResolveWhisperConversation(runtime, bnetAccountID, "BN")
  if existingKey ~= nil then
    return existingKey
  end

  local contact = identity.FromBattleNet(bnetAccountID, accountInfo)
  if contact.canonicalName == "" then
    return nil
  end

  local conversationKey = identity.BuildConversationKey(runtime.localProfileId, contact.contactKey)
  local now = type(runtime.now) == "function" and runtime.now() or 0
  Store.EnsureConversation(runtime.store, conversationKey, {
    channel = "BN",
    displayName = accountInfo.battleTag or accountInfo.accountName or tostring(bnetAccountID),
    bnetAccountID = bnetAccountID,
    battleTag = accountInfo.battleTag,
    gameAccountName = accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.characterName,
    lastActivityAt = now,
  })

  return conversationKey
end

ns.BootstrapAutoOpenConversationOps = ConversationOps

return ConversationOps
