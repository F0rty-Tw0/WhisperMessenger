local ConversationMerge = require("WhisperMessenger.Model.ConversationMerge")

local function line(id, sentAt)
  return { id = id, kind = "user", direction = "in", text = "t" .. sentAt, sentAt = sentAt }
end

local function test_lines_sharing_an_id_at_different_times_both_survive()
  local conversations = { old = { messages = { line("57", 100) } }, new = { messages = { line("57", 900) } } }
  ConversationMerge.Rekey(conversations, "old", "new", 50)
  assert(#conversations.new.messages == 2, "two lines from different sessions must both survive, got " .. #conversations.new.messages)
end

local function test_the_same_line_under_both_keys_is_kept_once()
  local conversations = { old = { messages = { line("57", 100) } }, new = { messages = { line("57", 100) } } }
  ConversationMerge.Rekey(conversations, "old", "new", 50)
  assert(#conversations.new.messages == 1, "a copy of one line must collapse to one")
end

return function()
  test_lines_sharing_an_id_at_different_times_both_survive()
  test_the_same_line_under_both_keys_is_kept_once()
end
