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
end
