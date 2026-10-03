local DuplicateCollapse = require("WhisperMessenger.Model.Filters.DuplicateCollapse")
local Store = require("WhisperMessenger.Model.ConversationStore")

local KEY = "channel::me::trade"

local function incoming(id, playerName, text, sentAt)
  return { id = id, direction = "in", kind = "user", playerName = playerName, text = text, sentAt = sentAt }
end

-- Appends like channel ingest will: collapse on a hit, else append + remember.
local function ingest(state, index, message)
  local conversation = Store.EnsureConversation(state, KEY)
  local senderKey = DuplicateCollapse.SenderKey(message.playerName)
  local normalized = DuplicateCollapse.NormalizeText(message.text)
  local hit = DuplicateCollapse.Find(index, conversation, senderKey, normalized)
  if hit then
    Store.CollapseRepeat(state, KEY, hit, message.sentAt)
    return hit
  end
  Store.AppendIncoming(state, KEY, message, false)
  DuplicateCollapse.Remember(index, KEY, senderKey, normalized, message)
  return message
end

return function()
  -- test_normalize_strips_color_links_and_punctuation
  do
    local normalized = DuplicateCollapse.NormalizeText("|cff0070dd|Hitem:1::|h[Fancy Sword]|h|r  WTS!!!")
    assert(normalized == "fancy sword wts", "got '" .. normalized .. "'")
  end

  -- test_normalize_ignores_case_whitespace_and_punctuation
  do
    assert(DuplicateCollapse.NormalizeText("WTS boost!!") == DuplicateCollapse.NormalizeText("wts   boost"), "variants normalize equal")
  end

  -- test_normalize_strips_raid_icon_tokens
  do
    assert(DuplicateCollapse.NormalizeText("{rt1} LFM {star} heroic") == "lfm heroic", "raid icons are ignored")
  end

  -- test_collapse_counts_repeats_in_place
  do
    local state = Store.New({ maxMessagesPerConversation = 50 })
    local index = {}
    local first = ingest(state, index, incoming("1", "Spammer", "WTS boost!!", 10))
    local conversation = state.conversations[KEY]
    local unreadBefore = conversation.unreadCount

    assert(ingest(state, index, incoming("2", "Spammer", "wts   boost", 20)) == first, "repeat collapses into the first row")
    assert(first.repeatCount == 2 and first.lastSeenAt == 20, "first repeat counts 2 and stamps last seen")
    assert(conversation.lastActivityAt == 20, "collapse bumps conversation activity")

    ingest(state, index, incoming("3", "spammer", "WTS BOOST", 30))
    assert(first.repeatCount == 3, "second repeat counts 3, got " .. tostring(first.repeatCount))
    assert(#conversation.messages == 1, "no new rows are appended")
    assert(conversation.unreadCount == unreadBefore, "collapse does not change unread")
  end

  -- test_trimmed_original_in_same_second_does_not_collapse (Review Focus 1)
  do
    local state = Store.New({ maxMessagesPerConversation = 2 })
    local index = {}
    local a = ingest(state, index, incoming("a", "Spammer", "WTS boost", 10))
    ingest(state, index, incoming("b", "Other", "LFM heroic", 10))
    ingest(state, index, incoming("c", "Third", "hello", 11))
    local conversation = state.conversations[KEY]
    assert(conversation.messages[1].id == "b", "A was trimmed at the cap")
    local entries = index[KEY]
    assert(entries[DuplicateCollapse.SenderKey("Spammer") .. "\0" .. "wts boost"] == a, "index still holds the detached A")

    local hit = DuplicateCollapse.Find(index, conversation, DuplicateCollapse.SenderKey("Spammer"), "wts boost")
    assert(hit == nil, "a trimmed message is never a collapse target")
  end

  -- test_fresh_index_rebuilds_from_stored_conversation (Review Focus 2)
  do
    local state = Store.New({ maxMessagesPerConversation = 50 })
    Store.AppendIncoming(state, KEY, incoming("old", "Spammer", "WTS boost!!", 10), false)
    Store.AppendIncoming(state, KEY, incoming("mine", "Me", "WTS boost!!", 11), false)
    state.conversations[KEY].messages[2].direction = "out"
    local stored = state.conversations[KEY].messages[1]

    local index = {}
    local hit = DuplicateCollapse.Find(index, state.conversations[KEY], DuplicateCollapse.SenderKey("Spammer"), "wts boost")
    assert(hit == stored, "the stored line from before the reload is found")
    local outgoing = DuplicateCollapse.Find(index, state.conversations[KEY], DuplicateCollapse.SenderKey("Me"), "wts boost")
    assert(outgoing == nil, "only incoming user messages are indexed")
  end

  -- test_index_stays_bounded_on_a_busy_chat
  do
    local state = Store.New({ maxMessagesPerConversation = 5 })
    local index = {}
    for n = 1, 500 do
      ingest(state, index, incoming(tostring(n), "Sender" .. (n % 7), "line number " .. n, n))
    end
    local entries = 0
    for _ in pairs(index[KEY]) do
      entries = entries + 1
    end
    assert(entries <= 33, "the index is rebuilt instead of growing, got " .. entries .. " entries")

    local last = state.conversations[KEY].messages[5]
    local hit = DuplicateCollapse.Find(index, state.conversations[KEY], DuplicateCollapse.SenderKey(last.playerName), "line number 500")
    assert(hit == last, "a retained line still collapses after a rebuild")
  end

  -- test_overfull_index_prunes_without_normalizing
  do
    local state = Store.New({ maxMessagesPerConversation = 5 })
    local index = {}
    for n = 1, 33 do
      ingest(state, index, incoming(tostring(n), "Sender" .. n, "line number " .. n, n))
    end
    local original = DuplicateCollapse.NormalizeText
    local normalizations = 0
    rawset(DuplicateCollapse, "NormalizeText", function(...)
      normalizations = normalizations + 1
      return original(...)
    end)
    local hit = DuplicateCollapse.Find(index, state.conversations[KEY], DuplicateCollapse.SenderKey("Sender33"), "line number 33")
    rawset(DuplicateCollapse, "NormalizeText", original)
    assert(normalizations == 0, "pruning re-normalizes nothing, got " .. normalizations)
    assert(hit == state.conversations[KEY].messages[5], "a retained line survives the prune")
    local entries = 0
    for _ in pairs(index[KEY]) do
      entries = entries + 1
    end
    assert(entries == 5, "only retained lines stay indexed, got " .. entries)
  end

  -- test_same_text_from_different_senders_never_matches
  do
    local state = Store.New({ maxMessagesPerConversation = 50 })
    local index = {}
    local first = ingest(state, index, incoming("1", "Alice", "WTS boost", 10))
    local second = ingest(state, index, incoming("2", "Bob", "WTS boost", 11))
    assert(second ~= first, "a different sender gets its own row")
    assert(first.repeatCount == nil, "the first row is not counted")
    assert(#state.conversations[KEY].messages == 2, "both lines are stored")
  end
end
