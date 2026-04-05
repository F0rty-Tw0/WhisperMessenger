-- Test channel context message injection logic:
-- verifies chronological insertion and expiry filtering.

local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

-- Replicate the production insertion logic from ConversationPane
local function insertChronologically(messages, channelMsg)
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

-- Use timestamps where channel messages are within 30-min TTL of "now"
local NOW = 10000

return function()
  -- test_channel_context_appended_at_end_when_most_recent
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Arthas-Area52", "WTS [Thunderfury] 50k", "Trade", 9500)

    local whispers = {
      { id = "1", direction = "in", kind = "user", text = "hey", sentAt = 9000 },
      { id = "2", direction = "out", kind = "user", text = "hi", sentAt = 9200 },
    }

    local entry = ChannelMessageStore.GetLatest(state, "arthas-area52", NOW)
    assert(entry ~= nil, "should find channel entry")

    local channelMsg = {
      id = "channel-ctx-" .. tostring(entry.sentAt),
      direction = "in",
      kind = "channel_context",
      text = entry.text,
      sentAt = entry.sentAt,
      playerName = "Arthas-Area52",
      channelLabel = entry.channelLabel,
    }

    local result = insertChronologically(whispers, channelMsg)
    assert(#result == 3, "should have 3 messages, got: " .. #result)
    assert(result[3].kind == "channel_context", "channel context should be last")
    assert(result[3].channelLabel == "Trade", "channel label mismatch")
    assert(result[3].text == "WTS [Thunderfury] 50k", "text mismatch")
  end

  -- test_channel_context_inserted_in_middle_chronologically
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Jaina-Proudmoore", "LFG M+15", "LookingForGroup", 9100)

    local whispers = {
      { id = "1", direction = "in", kind = "user", text = "hey", sentAt = 9000 },
      { id = "2", direction = "out", kind = "user", text = "hi", sentAt = 9200 },
    }

    local entry = ChannelMessageStore.GetLatest(state, "jaina-proudmoore", NOW)
    assert(entry ~= nil, "should find entry")

    local channelMsg = {
      id = "channel-ctx-" .. tostring(entry.sentAt),
      direction = "in",
      kind = "channel_context",
      text = entry.text,
      sentAt = entry.sentAt,
      channelLabel = entry.channelLabel,
    }

    local result = insertChronologically(whispers, channelMsg)
    assert(#result == 3, "should have 3 messages, got: " .. #result)
    assert(result[2].kind == "channel_context", "channel context should be in middle")
    assert(result[2].sentAt == 9100, "middle sentAt mismatch")
  end

  -- test_channel_context_inserted_at_start_when_oldest
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Thrall-Realm", "WTB leather", "Trade", 8900)

    local whispers = {
      { id = "1", direction = "in", kind = "user", text = "hey", sentAt = 9000 },
      { id = "2", direction = "out", kind = "user", text = "hi", sentAt = 9200 },
    }

    local entry = ChannelMessageStore.GetLatest(state, "thrall-realm", NOW)
    assert(entry ~= nil, "should find entry")

    local channelMsg = {
      id = "channel-ctx-" .. tostring(entry.sentAt),
      direction = "in",
      kind = "channel_context",
      text = entry.text,
      sentAt = entry.sentAt,
      channelLabel = entry.channelLabel,
    }

    local result = insertChronologically(whispers, channelMsg)
    assert(#result == 3, "should have 3 messages, got: " .. #result)
    assert(result[1].kind == "channel_context", "channel context should be first")
    assert(result[1].sentAt == 8900, "first sentAt mismatch")
  end

  -- test_expired_channel_message_not_returned
  do
    local state = ChannelMessageStore.New()
    local staleTime = NOW - 1801 -- 30 min + 1 second ago
    ChannelMessageStore.Record(state, "Thrall-Area52", "old post", "Trade", staleTime)

    local entry = ChannelMessageStore.GetLatest(state, "thrall-area52", NOW)
    assert(entry == nil, "expired channel message should not be returned")
  end

  -- test_empty_whisper_list_gets_channel_context_only
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Vol-Realm", "selling stuff", "Trade", 9800)

    local entry = ChannelMessageStore.GetLatest(state, "vol-realm", NOW)
    assert(entry ~= nil, "should find entry")

    local channelMsg = {
      id = "channel-ctx-" .. tostring(entry.sentAt),
      direction = "in",
      kind = "channel_context",
      text = entry.text,
      sentAt = entry.sentAt,
      channelLabel = entry.channelLabel,
    }

    local result = insertChronologically({}, channelMsg)
    assert(#result == 1, "should have 1 message, got: " .. #result)
    assert(result[1].kind == "channel_context", "should be channel context")
  end
end
