local ChannelContextMerger = require("WhisperMessenger.UI.ConversationPane.ChannelContextMerger")
local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

local NOW = 10000

local function makeDeps(state)
  return {
    channelMessageStore = ChannelMessageStore,
    channelMessageState = state,
    now = NOW,
  }
end

return function()
  ----------------------------------------------------------------------------
  -- Empty inputs / missing dependencies pass the original messages through.
  ----------------------------------------------------------------------------
  do
    local original = { { sentAt = 100 } }
    assert(ChannelContextMerger.Merge(original, nil, nil) == original, "nil contact + nil deps should return input unchanged")

    local nilStore = ChannelContextMerger.Merge(original, { displayName = "X" }, { channelMessageState = {}, now = NOW })
    assert(nilStore == original, "missing store should return input unchanged")

    local nilState = ChannelContextMerger.Merge(original, { displayName = "X" }, { channelMessageStore = ChannelMessageStore, now = NOW })
    assert(nilState == original, "missing state should return input unchanged")

    local state = ChannelMessageStore.New()
    local nilContact = ChannelContextMerger.Merge(original, nil, makeDeps(state))
    assert(nilContact == original, "nil contact should return input unchanged")

    local emptyName = ChannelContextMerger.Merge(original, { displayName = "" }, makeDeps(state))
    assert(emptyName == original, "empty contact name should return input unchanged")
  end

  ----------------------------------------------------------------------------
  -- No matching entry → original messages returned unchanged.
  ----------------------------------------------------------------------------
  do
    local state = ChannelMessageStore.New()
    local original = { { sentAt = 100, kind = "user" } }
    local result = ChannelContextMerger.Merge(original, { displayName = "Stranger-Realm" }, makeDeps(state))
    assert(result == original, "no entry recorded → return input unchanged, got new table")
  end

  ----------------------------------------------------------------------------
  -- Channel message inserted at the END when newer than all whispers.
  ----------------------------------------------------------------------------
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Arthas-Area52", "WTS [Thunderfury] 50k", "Trade", 9500)
    local whispers = {
      { id = "1", sentAt = 9000, kind = "user" },
      { id = "2", sentAt = 9200, kind = "user" },
    }
    local result = ChannelContextMerger.Merge(whispers, { displayName = "Arthas-Area52" }, makeDeps(state))
    assert(#result == 3, "expected 3 messages, got " .. #result)
    assert(result[3].kind == "channel_context", "channel_context should be last when most recent")
    assert(result[3].text == "WTS [Thunderfury] 50k", "text should match recorded entry")
    assert(result[3].channelLabel == "Trade", "channelLabel should match recorded entry")
    assert(result[3].direction == "in", "channel_context should always be incoming")
  end

  ----------------------------------------------------------------------------
  -- Channel message inserted in the MIDDLE when chronologically between.
  ----------------------------------------------------------------------------
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Jaina-Proudmoore", "LFG M+15", "LookingForGroup", 9100)
    local whispers = {
      { id = "1", sentAt = 9000, kind = "user" },
      { id = "2", sentAt = 9200, kind = "user" },
    }
    local result = ChannelContextMerger.Merge(whispers, { displayName = "Jaina-Proudmoore" }, makeDeps(state))
    assert(#result == 3, "expected 3 messages, got " .. #result)
    assert(result[2].kind == "channel_context", "channel_context should be in the middle")
    assert(result[2].sentAt == 9100, "middle sentAt should be 9100, got " .. tostring(result[2].sentAt))
  end

  ----------------------------------------------------------------------------
  -- Channel message inserted at the START when older than all whispers.
  ----------------------------------------------------------------------------
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Thrall-Realm", "WTB leather", "Trade", 8900)
    local whispers = {
      { id = "1", sentAt = 9000, kind = "user" },
      { id = "2", sentAt = 9200, kind = "user" },
    }
    local result = ChannelContextMerger.Merge(whispers, { displayName = "Thrall-Realm" }, makeDeps(state))
    assert(#result == 3, "expected 3 messages, got " .. #result)
    assert(result[1].kind == "channel_context", "channel_context should be first when oldest")
    assert(result[1].sentAt == 8900, "first sentAt should be 8900")
  end

  ----------------------------------------------------------------------------
  -- gameAccountName takes priority over displayName for lookup
  -- (BNet contacts: displayName is the BNet handle, gameAccountName is the
  -- in-game character name we recorded under).
  ----------------------------------------------------------------------------
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Ingame-Realm", "ingame chat", "Trade", 9300)
    local whispers = { { id = "1", sentAt = 9000, kind = "user" } }
    local contact = { displayName = "BNetHandle", gameAccountName = "Ingame-Realm" }
    local result = ChannelContextMerger.Merge(whispers, contact, makeDeps(state))
    assert(#result == 2, "should match via gameAccountName, expected 2 messages, got " .. #result)
    assert(result[2].kind == "channel_context", "context message should be present")
  end

  ----------------------------------------------------------------------------
  -- Empty whisper list still gets the channel context message.
  ----------------------------------------------------------------------------
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Vol-Realm", "selling stuff", "Trade", 9800)
    local result = ChannelContextMerger.Merge({}, { displayName = "Vol-Realm" }, makeDeps(state))
    assert(#result == 1, "empty input should yield 1 channel_context message")
    assert(result[1].kind == "channel_context", "the single entry should be the channel_context")
  end

  ----------------------------------------------------------------------------
  -- Repeated merges of the same store entry reuse the built channel message.
  -- The transcript diffs message identity, so a fresh table every refresh would
  -- mark that row changed and force a full bubble relayout each background tick.
  ----------------------------------------------------------------------------
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Cache-Realm", "same entry", "Trade", 9700)
    local contact = { displayName = "Cache-Realm" }
    local whispers = { { id = "1", sentAt = 9000, kind = "user" } }

    local first = ChannelContextMerger.Merge(whispers, contact, makeDeps(state))
    local second = ChannelContextMerger.Merge(whispers, contact, makeDeps(state))
    assert(first[2].kind == "channel_context", "expected a channel_context entry")
    assert(first[2] == second[2], "same store entry should reuse the same channel message table")

    ChannelMessageStore.Record(state, "Cache-Realm", "newer entry", "Trade", 9750)
    local third = ChannelContextMerger.Merge(whispers, contact, makeDeps(state))
    assert(third[2] ~= second[2], "a newer store entry should build a fresh channel message")
    assert(third[2].text == "newer entry", "the rebuilt message should carry the new text")
  end

  ----------------------------------------------------------------------------
  -- A channel chat never merges a sender's channel post: its own lines are
  -- the channel.
  ----------------------------------------------------------------------------
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Trade", "WTS ore", "Trade", 9800)
    local messages = { { id = "1", sentAt = 9000, kind = "user" } }
    local result = ChannelContextMerger.Merge(messages, { displayName = "Trade", channel = "CHANNEL" }, makeDeps(state))
    assert(result == messages, "a channel chat gets its messages back unchanged")
  end

  ----------------------------------------------------------------------------
  -- Show channel context off: nothing is merged, nothing is saved, saved lines
  -- are hidden (not deleted), and turning it back on shows them again.
  ----------------------------------------------------------------------------
  local function countContext(messages)
    local count = 0
    for _, message in ipairs(messages) do
      if message.kind == "channel_context" then
        count = count + 1
      end
    end
    return count
  end

  local function disabledDeps(state, conversation)
    local deps = makeDeps(state)
    deps.enabled = false
    deps.conversation = conversation
    return deps
  end

  -- test_disabled_merges_nothing
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Off-Realm", "WTS ore", "Trade", 9500)
    local whispers = { { id = "1", sentAt = 9000, kind = "user" } }
    local result = ChannelContextMerger.Merge(whispers, { displayName = "Off-Realm" }, disabledDeps(state))
    assert(countContext(result) == 0, "enabled = false must not merge a channel line")
  end

  -- test_disabled_persists_nothing
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Keep-Realm", "WTS ore", "Trade", 9500)
    local conversation = { channel = "WOW", messages = { { id = "1", sentAt = 9000, kind = "user" } } }
    ChannelContextMerger.Merge(conversation.messages, { displayName = "Keep-Realm" }, disabledDeps(state, conversation))
    assert(#conversation.messages == 1, "enabled = false must not save a channel line into the conversation")
  end

  -- test_disabled_hides_saved_context_line
  do
    local state = ChannelMessageStore.New()
    local saved = { id = "channel-ctx-9500", kind = "channel_context", text = "old", sentAt = 9500 }
    local conversation = { channel = "WOW", messages = { { id = "1", sentAt = 9000, kind = "user" }, saved } }
    local result = ChannelContextMerger.Merge(conversation.messages, { displayName = "Hide-Realm" }, disabledDeps(state, conversation))
    assert(countContext(result) == 0, "a saved channel line must be hidden while disabled")
    assert(#result == 1 and result[1].id == "1", "the other messages must stay")
    assert(#conversation.messages == 2 and conversation.messages[2] == saved, "the stored conversation must keep the saved line")
  end

  -- test_disabled_without_context_returns_same_table
  do
    local state = ChannelMessageStore.New()
    local whispers = { { id = "1", sentAt = 9000, kind = "user" } }
    local result = ChannelContextMerger.Merge(whispers, { displayName = "Plain-Realm" }, disabledDeps(state))
    assert(result == whispers, "no channel line to hide: the same table comes back")
  end

  -- test_reenabled_shows_saved_line_again
  do
    local state = ChannelMessageStore.New()
    local saved = { id = "channel-ctx-9500", kind = "channel_context", text = "old", sentAt = 9500 }
    local conversation = { channel = "WOW", messages = { { id = "1", sentAt = 9000, kind = "user" }, saved } }
    local contact = { displayName = "Back-Realm" }
    ChannelContextMerger.Merge(conversation.messages, contact, disabledDeps(state, conversation))

    local deps = makeDeps(state)
    deps.enabled = true
    deps.conversation = conversation
    local result = ChannelContextMerger.Merge(conversation.messages, contact, deps)
    assert(countContext(result) == 1, "re-enabled: the saved channel line shows again")
  end

  -- test_for_pane_passes_enabled_to_merge
  do
    local saved = { id = "channel-ctx-9500", kind = "channel_context", text = "old", sentAt = 9500 }
    local messages = { { id = "1", sentAt = 9000, kind = "user" }, saved }
    local result = ChannelContextMerger.ForPane(messages, { displayName = "Pane-Realm" }, { messages = messages }, false)
    assert(countContext(result) == 0, "ForPane with the option off must hide the saved channel line")
  end
end
