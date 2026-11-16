local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationMerge = ns.ConversationMerge or require("WhisperMessenger.Model.ConversationMerge")

-- Moves Battle.net conversations stored under a numeric account ID to their
-- battleTag key once a friend scan can name them, and points the session
-- state that held the old key at the new one.
local BNetRekey = {}

-- BN whispers that arrived before the friend list resolved are keyed by the
-- session-scoped numeric account ID (no battleTag was available). Once the
-- friend list is readable, fold those orphans into the stable battleTag
-- conversation so history isn't split — and isn't stranded next session
-- when the numeric ID changes.
-- Returns { [oldKey] = newKey } for every conversation that moved or merged.
function BNetRekey.RekeyOrphans(store, friendMap, Identity, maxMessages)
  local conversations = store.conversations
  local tagById = {}
  for battleTag, friend in pairs(friendMap) do
    if friend.bnetAccountID ~= nil then
      tagById[friend.bnetAccountID] = battleTag
    end
  end

  local moves = {}
  for key, conversation in pairs(conversations) do
    if conversation.channel == "BN" and conversation.battleTag == nil then
      local battleTag = conversation.bnetAccountID and tagById[conversation.bnetAccountID]
      if battleTag then
        local contact = Identity.FromBattleNet(conversation.bnetAccountID, { battleTag = battleTag })
        local newKey = Identity.BuildConversationKey(nil, contact.contactKey)
        if newKey ~= key then
          moves[key] = { newKey = newKey, battleTag = battleTag }
        end
      end
    end
  end

  local mappings = {}
  for oldKey, move in pairs(moves) do
    local conversation = conversations[oldKey]
    if conversation then
      conversation.battleTag = move.battleTag
      if conversation.displayName == nil or conversation.displayName == tostring(conversation.bnetAccountID) then
        conversation.displayName = move.battleTag
      end
      local rekeyed = ConversationMerge.Rekey(conversations, oldKey, move.newKey, maxMessages, store.messageRetentionAt)
      for sourceKey, destinationKey in pairs(rekeyed) do
        mappings[sourceKey] = destinationKey
      end
    end
  end

  return mappings
end

function BNetRekey.ApplyMappings(runtime, mappings)
  if runtime.activeConversationKey ~= nil then
    runtime.activeConversationKey = mappings[runtime.activeConversationKey] or runtime.activeConversationKey
  end
  if runtime.characterState and runtime.characterState.activeConversationKey ~= nil then
    runtime.characterState.activeConversationKey = mappings[runtime.characterState.activeConversationKey]
      or runtime.characterState.activeConversationKey
  end
  if runtime.lastIncomingWhisperKey ~= nil then
    runtime.lastIncomingWhisperKey = mappings[runtime.lastIncomingWhisperKey] or runtime.lastIncomingWhisperKey
  end
  local divider = runtime.unreadDivider
  if divider ~= nil and mappings[divider.conversationKey] ~= nil then
    divider.conversationKey = mappings[divider.conversationKey]
  end
  local onlineWatch = runtime.onlineWatch
  if onlineWatch ~= nil then
    for oldKey, newKey in pairs(mappings) do
      if onlineWatch[newKey] == nil then
        onlineWatch[newKey] = onlineWatch[oldKey]
      end
      onlineWatch[oldKey] = nil
    end
  end
end

ns.BootstrapLifecycleHandlersBNetRekey = BNetRekey
return BNetRekey
