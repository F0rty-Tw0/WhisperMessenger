local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelContextMerger = {}

local function lookupNameFor(selectedContact)
  if type(selectedContact) ~= "table" then
    return nil
  end
  local name = selectedContact.gameAccountName or selectedContact.displayName
  if type(name) ~= "string" or name == "" then
    return nil
  end
  return string.lower(name)
end

-- Merge a recent channel-context message into the chronological message list
-- for the selected contact. Returns the original messages table unchanged when
-- there is nothing to merge (no store, no state, no contact, no recent entry).
function ChannelContextMerger.Merge(messages, selectedContact, deps)
  deps = deps or {}
  local store = deps.channelMessageStore
  local state = deps.channelMessageState
  if not store or not state then
    return messages
  end

  local lookupName = lookupNameFor(selectedContact)
  if lookupName == nil then
    return messages
  end

  local entry = store.GetLatest(state, lookupName, deps.now)
  if not entry then
    return messages
  end

  local channelMsg = {
    id = "channel-ctx-" .. tostring(entry.sentAt),
    direction = "in",
    kind = "channel_context",
    text = entry.text,
    sentAt = entry.sentAt,
    playerName = selectedContact.displayName or entry.playerName,
    channelLabel = entry.channelLabel,
  }

  local result = {}
  local inserted = false
  for _, m in ipairs(messages) do
    if not inserted and (channelMsg.sentAt or 0) < (m.sentAt or 0) then
      result[#result + 1] = channelMsg
      inserted = true
    end
    result[#result + 1] = m
  end
  if not inserted then
    result[#result + 1] = channelMsg
  end
  return result
end

ns.ConversationPaneChannelContextMerger = ChannelContextMerger
return ChannelContextMerger
