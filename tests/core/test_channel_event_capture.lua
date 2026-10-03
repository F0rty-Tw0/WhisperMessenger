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

local Store = require("WhisperMessenger.Model.ConversationStore")
local IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList")

local TRADE_KEY = "channel::arthas-area52::trade"

-- All 18 CHAT_MSG_CHANNEL arguments, as the live client sends them.
local function tradeLine(runtime, text, sender, lineID, zoneChannelID)
  return EventBridge.RouteChannelEvent(
    runtime,
    "CHAT_MSG_CHANNEL",
    text,
    sender,
    "Common",
    "2. Trade - Stormwind City",
    sender,
    "",
    zoneChannelID,
    2,
    "Trade - Stormwind City",
    7,
    lineID,
    "Player-1-" .. sender,
    0,
    false,
    false,
    false
  )
end

local function makeRuntime()
  local refreshKeys = {}
  local runtime = {
    localProfileId = "arthas-area52",
    localPlayerGuid = "Player-1-SELF",
    store = Store.New({ maxMessagesPerConversation = 50 }),
    channelMessageStore = ChannelMessageStore.New(),
    accountState = { settings = { enabledChannels = { trade = true } }, filters = { ignored = {}, rules = {} } },
    collapseIndex = {},
    now = function()
      return 100
    end,
    scheduleIncomingRefresh = function(key)
      refreshKeys[#refreshKeys + 1] = key
    end,
  }
  return runtime, refreshKeys
end

return function()
  -- test_enabled_trade_line_creates_chat_and_schedules_one_refresh
  do
    local runtime, refreshKeys = makeRuntime()
    tradeLine(runtime, "WTS ore", "Seller", 8101, 2)
    assert(runtime.store.conversations[TRADE_KEY] ~= nil, "the Trade line becomes a channel chat")
    assert(#refreshKeys == 1 and refreshKeys[1] == TRADE_KEY, "one keyed refresh is scheduled")
  end

  -- test_suspended_ingest_still_records_channel_context
  do
    local runtime, refreshKeys = makeRuntime()
    runtime.isChannelIngestSuspended = function()
      return true
    end
    tradeLine(runtime, "WTS ore", "Seller", 8102, 2)
    assert(ChannelMessageStore.GetLatest(runtime.channelMessageStore, "seller") ~= nil, "the line is still kept as context")
    assert(next(runtime.store.conversations) == nil, "no channel chat while suspended")
    assert(#refreshKeys == 0, "no refresh while suspended")
  end

  -- test_missing_zone_id_keys_by_name
  do
    local runtime = makeRuntime()
    runtime.accountState.settings.enabledChannels = { ["c:trade"] = true }
    tradeLine(runtime, "WTS ore", "Seller", 8103, nil)
    assert(runtime.store.conversations["channel::arthas-area52::c:trade"] ~= nil, "without a zone ID the chat keys by name")
  end

  -- test_ignored_sender_is_not_kept_as_context
  do
    local runtime = makeRuntime()
    runtime.accountState.settings.enabledChannels = {}
    IgnoreList.Add(runtime.accountState.filters, "Spammer", { now = 1 })
    assert(tradeLine(runtime, "cheap gold", "Spammer", 8104, 2), "the dropped line counts as handled")
    assert(ChannelMessageStore.GetLatest(runtime.channelMessageStore, "spammer") == nil, "an ignored sender's line is not kept")
  end

  -- test_channel_mention_alerts
  do
    local flashes = 0
    local savedUnitName = _G.UnitName
    rawset(_G, "UnitName", function()
      return "Arthas"
    end)
    rawset(_G, "FlashClientIcon", function()
      flashes = flashes + 1
    end)
    local runtime = makeRuntime()
    tradeLine(runtime, "WTS ore", "Seller", 8105, 2)
    assert(flashes == 0, "a plain channel line is silent")
    tradeLine(runtime, "Arthas you still need ore?", "Seller", 8106, 2)
    assert(flashes == 1, "a channel line naming the player alerts")
    -- test_muted_channel_mention_is_silent
    runtime.store.conversations[TRADE_KEY].muted = true
    tradeLine(runtime, "Arthas, ore?", "Buyer", 8107, 2)
    assert(flashes == 1, "a muted channel chat never alerts, even on a mention")
    rawset(_G, "UnitName", savedUnitName)
    rawset(_G, "FlashClientIcon", nil)
  end

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
    assert(entry.channelLabel == "Trade", "channelLabel should extract base name, got: " .. tostring(entry.channelLabel))
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

    -- "4. LookingForGroup" (no zone suffix) → "LookingForGroup" (number prefix still stripped)
    EventBridge.RouteChannelEvent(runtime, "CHAT_MSG_CHANNEL", "msg3", "P3-Realm", "", "4. LookingForGroup")
    local e3 = ChannelMessageStore.GetLatest(runtime.channelMessageStore, "p3-realm")
    assert(e3.channelLabel == "LookingForGroup", "custom channel should drop its number, got: " .. tostring(e3.channelLabel))
  end
end
