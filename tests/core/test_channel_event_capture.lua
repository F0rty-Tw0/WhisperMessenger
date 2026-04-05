local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

-- Minimal EventBridge test: verify RouteChannelEvent records to the store
local EventBridge
do
  -- Stub ns and dependencies so EventBridge can load
  package.preload["WhisperMessenger.Transport.BNetResolver"] = function()
    return {
      NormalizeAvailabilityStatus = function(s)
        return s
      end,
      ResolveAccountInfo = function()
        return nil
      end,
      ResolvePlayerInfo = function()
        return {}
      end,
    }
  end
  package.preload["WhisperMessenger.Core.SoundPlayer"] = function()
    return { Play = function() end }
  end
  EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
end

return function()
  -- test_route_channel_event_records_message
  do
    local clockTime = 5000
    local runtime = {
      channelMessageStore = ChannelMessageStore.New(),
      now = function()
        return clockTime
      end,
    }

    local result = EventBridge.RouteChannelEvent(
      runtime,
      "CHAT_MSG_CHANNEL",
      "WTS [Thunderfury] 50k", -- text
      "Arthas-Area52", -- senderName
      "", -- languageName
      "2. Trade - Stormwind City" -- channelString
    )

    assert(result ~= nil, "should return store on success")

    local entry = ChannelMessageStore.GetLatest(runtime.channelMessageStore, "arthas-area52")
    assert(entry ~= nil, "should have recorded the message")
    assert(entry.text == "WTS [Thunderfury] 50k", "text mismatch: " .. tostring(entry.text))
    assert(
      entry.channelLabel == "Trade",
      "channelLabel should extract base name, got: " .. tostring(entry.channelLabel)
    )
    assert(entry.playerName == "Arthas-Area52", "playerName mismatch")
    assert(entry.sentAt == 5000, "sentAt should use runtime.now()")
  end

  -- test_route_channel_event_ignores_non_channel_events
  do
    local runtime = {
      channelMessageStore = ChannelMessageStore.New(),
      now = function()
        return 1000
      end,
    }

    local result = EventBridge.RouteChannelEvent(runtime, "CHAT_MSG_WHISPER", "hi", "Arthas-Area52", "", "")
    assert(result == nil, "should return nil for non-channel events")
  end

  -- test_route_channel_event_handles_nil_runtime
  do
    local result = EventBridge.RouteChannelEvent(nil, "CHAT_MSG_CHANNEL", "msg", "Player", "", "1. General")
    assert(result == nil, "should return nil for nil runtime")
  end

  -- test_channel_label_extraction_various_formats
  do
    local runtime = {
      channelMessageStore = ChannelMessageStore.New(),
      now = function()
        return 1000
      end,
    }

    -- "2. Trade - Stormwind City" → "Trade"
    EventBridge.RouteChannelEvent(runtime, "CHAT_MSG_CHANNEL", "msg1", "P1-Realm", "", "2. Trade - Stormwind City")
    local e1 = ChannelMessageStore.GetLatest(runtime.channelMessageStore, "p1-realm")
    assert(e1.channelLabel == "Trade", "expected 'Trade', got: " .. tostring(e1.channelLabel))

    -- "1. General - Dornogal" → "General"
    EventBridge.RouteChannelEvent(runtime, "CHAT_MSG_CHANNEL", "msg2", "P2-Realm", "", "1. General - Dornogal")
    local e2 = ChannelMessageStore.GetLatest(runtime.channelMessageStore, "p2-realm")
    assert(e2.channelLabel == "General", "expected 'General', got: " .. tostring(e2.channelLabel))

    -- "4. LookingForGroup" (no zone suffix) → "4. LookingForGroup" (full string as fallback)
    EventBridge.RouteChannelEvent(runtime, "CHAT_MSG_CHANNEL", "msg3", "P3-Realm", "", "4. LookingForGroup")
    local e3 = ChannelMessageStore.GetLatest(runtime.channelMessageStore, "p3-realm")
    assert(
      e3.channelLabel == "4. LookingForGroup",
      "fallback should use full string, got: " .. tostring(e3.channelLabel)
    )
  end
end
