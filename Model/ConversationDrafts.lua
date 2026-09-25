local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")

-- Unsent composer text, one per conversation. Stored on the conversation
-- record itself, so it is saved with the conversation and removed with it
-- (remove, Clear All Chats, clear on logout, retention).
local ConversationDrafts = {}

function ConversationDrafts.Get(store, conversationKey)
  local conversation = Store.Find(store, conversationKey)
  return conversation and conversation.draft or nil
end

-- Whitespace-only (or non-string) text clears the draft. Never creates a
-- conversation. The pcall keeps a chat-lockdown secret string (which throws
-- on any string op) out of SavedVariables.
function ConversationDrafts.Set(store, conversationKey, text)
  local conversation = Store.Find(store, conversationKey)
  if conversation == nil then
    return
  end
  local ok, hasText = pcall(string.find, text, "%S")
  if type(text) == "string" and ok and hasText then
    conversation.draft = text
  else
    conversation.draft = nil
  end
end

ns.ConversationDrafts = ConversationDrafts
return ConversationDrafts
