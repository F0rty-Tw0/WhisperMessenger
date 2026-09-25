local Drafts = require("WhisperMessenger.Model.ConversationDrafts")
local Store = require("WhisperMessenger.Model.ConversationStore")

local function newStore()
  local store = Store.New({ maxMessagesPerConversation = 50, maxConversations = 10, messageMaxAge = 86400, conversationMaxAge = 86400 })
  Store.EnsureConversation(store, "me::WOW::arthas")
  return store
end

return function()
  -- test_set_then_get_returns_draft_text
  local store = newStore()
  Drafts.Set(store, "me::WOW::arthas", "half typed")
  assert(Drafts.Get(store, "me::WOW::arthas") == "half typed", "draft should round-trip")

  -- test_draft_lives_on_conversation_record_so_it_persists_with_saved_variables
  assert(store.conversations["me::WOW::arthas"].draft == "half typed", "draft should be stored on the saved conversation record")

  -- test_whitespace_only_text_clears_draft
  Drafts.Set(store, "me::WOW::arthas", "   \t ")
  assert(Drafts.Get(store, "me::WOW::arthas") == nil, "whitespace-only text is no draft")

  -- test_empty_text_clears_draft
  Drafts.Set(store, "me::WOW::arthas", "again")
  Drafts.Set(store, "me::WOW::arthas", "")
  assert(Drafts.Get(store, "me::WOW::arthas") == nil, "empty text clears the draft")

  -- test_non_string_text_clears_draft
  Drafts.Set(store, "me::WOW::arthas", "again")
  Drafts.Set(store, "me::WOW::arthas", nil)
  assert(Drafts.Get(store, "me::WOW::arthas") == nil, "nil text clears the draft")

  -- test_set_never_creates_a_conversation
  Drafts.Set(store, "me::WOW::nobody", "hello")
  assert(store.conversations["me::WOW::nobody"] == nil, "a draft must not create a conversation")
  assert(Drafts.Get(store, "me::WOW::nobody") == nil, "unknown conversation has no draft")

  -- test_nil_key_is_ignored
  Drafts.Set(store, nil, "hello")
  assert(Drafts.Get(store, nil) == nil, "nil key has no draft")

  -- test_removing_conversation_removes_its_draft
  Drafts.Set(store, "me::WOW::arthas", "bye")
  Store.Remove(store, "me::WOW::arthas")
  Store.EnsureConversation(store, "me::WOW::arthas")
  assert(Drafts.Get(store, "me::WOW::arthas") == nil, "removed conversation takes its draft with it")
end
