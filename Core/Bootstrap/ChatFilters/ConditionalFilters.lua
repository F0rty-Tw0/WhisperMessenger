local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IncomingFilter = ns.IncomingFilter or require("WhisperMessenger.Core.Ingest.IncomingFilter")
local ChannelChatIngest = ns.ChannelChatIngest or require("WhisperMessenger.Core.Ingest.ChannelChatIngest")
local ChannelKey = ns.ChannelChatIngestChannelKey or require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")
local Direction = ns.GroupChatIngestDirection or require("WhisperMessenger.Core.Ingest.GroupChatIngest.Direction")
local FilterApi = ns.BootstrapChatFilterApi or require("WhisperMessenger.Core.Bootstrap.ChatFilters.FilterApi")

-- Chat-frame filters that hide only some lines: channels the player reads as
-- chats (when "Hide channels from default chat" is on), ignored players and
-- keyword-rule matches. Never registered on whisper events: a whisper filter
-- that returns false taints SetLastTellTarget. Each body runs once per chat
-- frame per line, so it builds no tables and reuses the lineID decision
-- cache; anything unexpected (non-string or secret payload) shows the line.
local ConditionalFilters = {}

local CHANNEL_EVENT = "CHAT_MSG_CHANNEL"
local CHANNEL_EVENTS = { CHANNEL_EVENT }
local SPEECH_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE" }
local PASS = "pass"

local ipairs = ipairs
local next = next
local pairs = pairs

local function anyTrue(map)
  for _, value in pairs(type(map) == "table" and map or {}) do
    if value == true then
      return true
    end
  end
  return false
end

local function anyEnabledRule(rules)
  for _, rule in ipairs(type(rules) == "table" and rules or {}) do
    if rule.enabled then
      return true
    end
  end
  return false
end

-- Whether the channel filter and the say/yell/emote filter have anything to
-- hide: channels need a hidden channel chat, an ignored player or an enabled
-- rule; say, yell and emote only ever hide ignored players.
function ConditionalFilters.Needs(accountState)
  local settings = accountState and accountState.settings or {}
  local state = accountState and accountState.filters or {}
  local hasIgnored = type(state.ignored) == "table" and next(state.ignored) ~= nil
  local hidesChannels = settings.hideChannelsFromDefaultChat == true and anyTrue(settings.enabledChannels)
  return hasIgnored or hidesChannels or anyEnabledRule(state.rules), hasIgnored
end

local function isSecret(value)
  local check = _G.issecretvalue
  return type(check) == "function" and check(value) == true
end

local function isUnsafe(text, playerName, guid)
  if isSecret(text) or isSecret(playerName) or isSecret(guid) then
    return true
  end
  return type(text) ~= "string" or type(playerName) ~= "string"
end

local function hidesChannel(runtime, zoneChannelID, channelBaseName)
  local settings = runtime.accountState and runtime.accountState.settings
  if not (settings and settings.hideChannelsFromDefaultChat == true) then
    return false
  end
  if not ChannelChatIngest.IsEnabled(runtime, zoneChannelID, channelBaseName) then
    return false
  end
  -- A paused channel chat stores nothing, so the line stays in game chat.
  return not (runtime.isChannelIngestSuspended and runtime.isChannelIngestSuspended())
end

-- kind "channel" applies the ignore list and keyword rules; "speech" only
-- the ignore list. Later chat frames read the first frame's cached decision.
local function filtered(runtime, kind, eventName, text, playerName, label, lineID, guid)
  local cached = IncomingFilter.DecisionFor(lineID)
  if cached ~= nil then
    return cached ~= PASS
  end
  local isSelf = Direction.IsLocalSender(eventName, guid, nil, runtime)
  return IncomingFilter.Evaluate(runtime, kind, playerName, text, lineID, label, isSelf) ~= PASS
end

function ConditionalFilters.New(runtime)
  local filters = {}

  -- Blizzard passes (frame, event, ...payload): payload arg N is parameter N + 2.
  function filters.Channel(_frame, _event, text, playerName, _, _, _, _, zoneChannelID, _, channelBaseName, _, lineID, guid)
    if isSecret(channelBaseName) or isUnsafe(text, playerName, guid) then
      return false
    end
    if hidesChannel(runtime, zoneChannelID, channelBaseName) then
      return true
    end
    return filtered(runtime, "channel", CHANNEL_EVENT, text, playerName, ChannelKey.BaseName(channelBaseName), lineID, guid)
  end

  -- CHAT_MSG_SAY, CHAT_MSG_YELL and CHAT_MSG_EMOTE share the channel layout.
  function filters.Speech(_frame, event, text, playerName, _, _, _, _, _, _, _, _, lineID, guid)
    if isUnsafe(text, playerName, guid) then
      return false
    end
    return filtered(runtime, "speech", event, text, playerName, event, lineID, guid)
  end

  local registered = { channel = false, speech = false }

  local function setGroup(name, events, fn, want)
    if registered[name] == want then
      return
    end
    for _, event in ipairs(events) do
      if want then
        FilterApi.Add(event, fn)
      else
        FilterApi.Remove(event, fn)
      end
    end
    registered[name] = want
  end

  -- allowed: false in restricted content, while suspended, or with the
  -- selective-hiding switch off; every conditional filter is removed then.
  function filters.Sync(allowed)
    local channel, speech = false, false
    if allowed and FilterApi.IsAvailable() then
      channel, speech = ConditionalFilters.Needs(runtime.accountState)
    end
    setGroup("channel", CHANNEL_EVENTS, filters.Channel, channel)
    setGroup("speech", SPEECH_EVENTS, filters.Speech, speech)
  end

  return filters
end

ns.BootstrapChatFiltersConditionalFilters = ConditionalFilters
return ConditionalFilters
