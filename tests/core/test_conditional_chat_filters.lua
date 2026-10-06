local ConditionalFilters = require("WhisperMessenger.Core.Bootstrap.ChatFilters.ConditionalFilters")
local IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList")
local KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules")

-- Bodies of the chat-frame filters for channels, say, yell and emote: hide
-- lines of channels shown as chats (when hiding is on), ignored players and
-- rule matches; fail open on anything unexpected.
local SELF_GUID = "Player-1-0000SELF"
local OTHER_GUID = "Player-1-0000OTHER"

local function makeRuntime(settings)
  local filters = { ignored = {}, rules = {} }
  local runtime = {
    accountState = { settings = settings or {}, filters = filters },
    localPlayerGuid = SELF_GUID,
    now = function()
      return 500
    end,
  }
  return runtime, filters
end

-- Blizzard calls filter(frame, event, ...payload); CHAT_MSG_CHANNEL payload:
-- 1 text, 2 playerName, 4 channelName, 7 zoneChannelID, 8 channelIndex,
-- 9 channelBaseName, 11 lineID, 12 guid.
local function channelLine(filters, line)
  return filters.Channel(
    {},
    "CHAT_MSG_CHANNEL",
    line.text,
    line.player,
    "",
    "2. Trade - Stormwind City",
    "",
    "",
    line.zoneID or 2,
    2,
    line.baseName or "Trade - Stormwind City",
    0,
    line.lineID,
    line.guid or OTHER_GUID
  )
end

local function speechLine(filters, event, line)
  return filters.Speech({}, event, line.text, line.player, "", "", "", "", 0, 0, "", 0, line.lineID, line.guid or OTHER_GUID)
end

return function()
  -- test_enabled_channel_line_is_hidden_with_hiding_on
  do
    local runtime = makeRuntime({ hideChannelsFromDefaultChat = true, enabledChannels = { trade = true } })
    local filters = ConditionalFilters.New(runtime)
    assert(channelLine(filters, { text = "lfm", player = "Friend", lineID = 1 }) == true, "a Trade line shown as a chat is hidden")
  end

  -- test_enabled_channel_line_shows_with_hiding_off
  do
    local runtime = makeRuntime({ hideChannelsFromDefaultChat = false, enabledChannels = { trade = true } })
    local filters = ConditionalFilters.New(runtime)
    assert(channelLine(filters, { text = "lfm", player = "Friend", lineID = 2 }) == false, "hiding off keeps the line")
  end

  -- test_unset_hide_channels_keeps_channel_lines
  do
    local runtime = makeRuntime({ enabledChannels = { trade = true } })
    local filters = ConditionalFilters.New(runtime)
    assert(ConditionalFilters.Needs(runtime.accountState) == false, "no saved choice needs no channel filter")
    assert(channelLine(filters, { text = "lfm", player = "Friend", lineID = 20 }) == false, "no saved choice keeps the line")
  end

  -- test_clean_line_in_disabled_channel_shows
  do
    local runtime = makeRuntime({ hideChannelsFromDefaultChat = true, enabledChannels = { general = true } })
    local filters = ConditionalFilters.New(runtime)
    assert(channelLine(filters, { text = "lfm", player = "Friend", lineID = 3 }) == false, "a channel that is not a chat shows")
  end

  -- test_enabled_channel_shows_while_channel_chats_are_paused
  do
    local runtime = makeRuntime({ hideChannelsFromDefaultChat = true, enabledChannels = { trade = true } })
    runtime.isChannelIngestSuspended = function()
      return true
    end
    local filters = ConditionalFilters.New(runtime)
    assert(channelLine(filters, { text = "lfm", player = "Friend", lineID = 4 }) == false, "a paused channel chat keeps the line in game chat")
  end

  -- test_ignored_sender_in_channel_is_hidden
  do
    local runtime, state = makeRuntime({})
    local entry = assert(IgnoreList.Add(state, "Spammer", { now = 1 }))
    local filters = ConditionalFilters.New(runtime)
    assert(channelLine(filters, { text = "cheap gold", player = "Spammer", lineID = 5 }) == true, "ignored sender hidden")
    assert(entry.blocked == 1 and entry.lastChannel == "Trade", "the entry records the line and channel")
  end

  -- test_rule_match_in_channel_is_hidden
  do
    local runtime, state = makeRuntime({})
    KeywordRules.Add(state, "wts boost")
    local filters = ConditionalFilters.New(runtime)
    assert(channelLine(filters, { text = "WTS mythic boost", player = "Seller", lineID = 6 }) == true, "rule match hidden")
  end

  -- test_own_channel_line_is_never_hidden_by_ignore_or_rules
  do
    local runtime, state = makeRuntime({})
    IgnoreList.Add(state, "Me", { now = 1 })
    KeywordRules.Add(state, "wts boost")
    local filters = ConditionalFilters.New(runtime)
    local hidden = channelLine(filters, { text = "wts boost", player = "Me", lineID = 7, guid = SELF_GUID })
    assert(hidden == false, "the player's own line shows")
  end

  -- test_same_line_in_three_chat_frames_counts_once
  do
    local runtime, state = makeRuntime({})
    local entry = assert(IgnoreList.Add(state, "Spammer", { now = 1 }))
    local filters = ConditionalFilters.New(runtime)
    for _ = 1, 3 do
      assert(channelLine(filters, { text = "spam", player = "Spammer", lineID = 8 }) == true, "hidden in every frame")
    end
    assert(entry.blocked == 1, "three chat frames count one blocked line, got " .. entry.blocked)
  end

  -- test_non_string_payload_fails_open
  do
    local runtime, state = makeRuntime({ hideChannelsFromDefaultChat = true, enabledChannels = { trade = true } })
    IgnoreList.Add(state, "Spammer", { now = 1 })
    local filters = ConditionalFilters.New(runtime)
    assert(channelLine(filters, { text = nil, player = "Spammer", lineID = 9 }) == false, "missing text shows")
    assert(channelLine(filters, { text = "spam", player = 42, lineID = 10 }) == false, "non-string sender shows")
    assert(speechLine(filters, "CHAT_MSG_SAY", { text = {}, player = "Spammer", lineID = 11 }) == false, "table text shows")
  end

  -- test_secret_payload_fails_open_without_counting
  do
    local runtime, state = makeRuntime({ hideChannelsFromDefaultChat = true, enabledChannels = { trade = true } })
    local entry = assert(IgnoreList.Add(state, "Spammer", { now = 1 }))
    local filters = ConditionalFilters.New(runtime)
    rawset(_G, "issecretvalue", function(value)
      return value == "secret text"
    end)
    local ok, result = pcall(channelLine, filters, { text = "secret text", player = "Spammer", lineID = 12 })
    local speechOk, speechResult = pcall(speechLine, filters, "CHAT_MSG_SAY", { text = "secret text", player = "Spammer", lineID = 13 })
    rawset(_G, "issecretvalue", nil)
    assert(ok and result == false, "a secret channel line shows")
    assert(speechOk and speechResult == false, "a secret say line shows")
    assert(entry.blocked == 0, "a secret line is never evaluated")
  end

  -- test_ignored_sender_in_say_yell_and_emote_is_hidden
  do
    local runtime, state = makeRuntime({})
    IgnoreList.Add(state, "Spammer", { now = 1 })
    local filters = ConditionalFilters.New(runtime)
    assert(speechLine(filters, "CHAT_MSG_SAY", { text = "hi", player = "Spammer", lineID = 14 }) == true, "say hidden")
    assert(speechLine(filters, "CHAT_MSG_YELL", { text = "hi", player = "Spammer", lineID = 15 }) == true, "yell hidden")
    assert(speechLine(filters, "CHAT_MSG_EMOTE", { text = "waves", player = "Spammer", lineID = 16 }) == true, "emote hidden")
    assert(speechLine(filters, "CHAT_MSG_SAY", { text = "hi", player = "Friend", lineID = 17 }) == false, "others show")
  end

  -- test_rules_do_not_hide_say_lines
  do
    local runtime, state = makeRuntime({})
    KeywordRules.Add(state, "wts boost")
    local filters = ConditionalFilters.New(runtime)
    assert(speechLine(filters, "CHAT_MSG_SAY", { text = "wts boost", player = "Seller", lineID = 18 }) == false, "rules apply to channels only")
  end

  -- test_own_say_line_is_never_hidden
  do
    local runtime, state = makeRuntime({})
    IgnoreList.Add(state, "Me", { now = 1 })
    local filters = ConditionalFilters.New(runtime)
    assert(speechLine(filters, "CHAT_MSG_SAY", { text = "hi", player = "Me", lineID = 19, guid = SELF_GUID }) == false, "own say line shows")
  end
  -- test_malformed_saved_rule_fails_open
  do
    local runtime, state = makeRuntime({})
    state.rules[1] = { enabled = true, blocked = 0 }
    state.rules[2] = { enabled = true, blocked = 0, words = "spam" }
    local filters = ConditionalFilters.New(runtime)
    local ok, hidden = pcall(channelLine, filters, { text = "spam", player = "Seller", lineID = 20 })
    assert(ok, "a malformed rule does not throw: " .. tostring(hidden))
    assert(hidden == false, "a malformed rule shows the line")
  end

  -- test_secret_channel_name_fails_open
  do
    local runtime = makeRuntime({ hideChannelsFromDefaultChat = true, enabledChannels = { trade = true } })
    local filters = ConditionalFilters.New(runtime)
    local secretName = "Trade - Stormwind City"
    rawset(_G, "issecretvalue", function(value)
      return value == secretName
    end)
    local ok, hidden = pcall(channelLine, filters, { text = "lfm", player = "Friend", lineID = 21, baseName = secretName })
    rawset(_G, "issecretvalue", nil)
    assert(ok and hidden == false, "a secret channel name shows the line")
  end
end
