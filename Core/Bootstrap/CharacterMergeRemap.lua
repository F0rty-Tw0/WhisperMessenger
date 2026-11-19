local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BNetRekey = ns.BootstrapLifecycleHandlersBNetRekey or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.BNetRekey")
local PendingQueue = ns.MessageReactionsPendingQueue or require("WhisperMessenger.Model.MessageReactions.PendingQueue")

-- Once a character's chat folds into their Battle.net friend's chat, the
-- session state kept under the character's key moves to the friend's key.
local CharacterMergeRemap = {}

local ipairs = ipairs

-- Per-chat session maps where the friend's chat keeps its own value.
local MOVED_MAPS = {
  "sendStatusByConversation",
  "typingByConversation",
  "livePresencePeers",
  "lastAlertAtByConversation",
}

local function moveEntry(map, fromKey, toKey)
  if type(map) ~= "table" then
    return
  end
  if map[toKey] == nil then
    map[toKey] = map[fromKey]
  end
  map[fromKey] = nil
end

-- The character's waiting sends go after the friend's, in their order.
local function movePendingSends(pendingOutgoing, fromKey, toKey)
  if type(pendingOutgoing) ~= "table" or type(pendingOutgoing[fromKey]) ~= "table" then
    return
  end
  local queue = pendingOutgoing[toKey]
  if type(queue) ~= "table" then
    pendingOutgoing[toKey] = pendingOutgoing[fromKey]
  else
    for _, entry in ipairs(pendingOutgoing[fromKey]) do
      queue[#queue + 1] = entry
    end
  end
  pendingOutgoing[fromKey] = nil
end

local function clearEntry(map, key)
  if type(map) == "table" then
    map[key] = nil
  end
end

function CharacterMergeRemap.Apply(runtime, characterKey, bnetKey)
  if runtime == nil or characterKey == nil or bnetKey == nil or characterKey == bnetKey then
    return
  end
  BNetRekey.ApplyMappings(runtime, { [characterKey] = bnetKey })
  for _, field in ipairs(MOVED_MAPS) do
    moveEntry(runtime[field], characterKey, bnetKey)
  end
  movePendingSends(runtime.pendingOutgoing, characterKey, bnetKey)
  -- The expiry timer is bound to the character's key; a flag on the friend's
  -- chat with no timer behind it would block its later typing expiries.
  clearEntry(runtime.typingExpiryPending, characterKey)
  -- Rebuilt on demand, so dropped rather than moved.
  clearEntry(runtime.collapseIndex, characterKey)
  PendingQueue.RemapConversation(runtime, characterKey, bnetKey)
  local window = runtime.window
  if window and window.composer and window.composer.moveReply then
    window.composer.moveReply(characterKey, bnetKey)
  end
end

ns.BootstrapCharacterMergeRemap = CharacterMergeRemap
return CharacterMergeRemap
