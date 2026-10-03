local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelMessageStore = ns.ChannelMessageStore or require("WhisperMessenger.Model.ChannelMessageStore")
local ChannelChatIngest = ns.ChannelChatIngest or require("WhisperMessenger.Core.Ingest.ChannelChatIngest")
local Direction = ns.GroupChatIngestDirection or require("WhisperMessenger.Core.Ingest.GroupChatIngest.Direction")
local IncomingAlerts = ns.BootstrapEventBridgeIncomingAlerts or require("WhisperMessenger.Core.Bootstrap.EventBridge.IncomingAlerts")
local IncomingFilter = ns.IncomingFilter or require("WhisperMessenger.Core.Ingest.IncomingFilter")

-- Public channel lines: filtered first, then kept as whisper-chat context
-- (ChannelMessageStore) and, for channels the player turned on, stored as
-- channel chats.
local ChannelRouter = {}

local EVENT_NAME = "CHAT_MSG_CHANNEL"

-- "2. Trade - City" -> "Trade", "1. CraftScan" -> "CraftScan".
local function channelLabelFor(channelString)
  local label = string.match(channelString or "", "^%d+%.%s*(.-)%s*%-") or string.match(channelString or "", "^%d+%.%s*(.+)$") or channelString or ""
  if label == "" then
    label = channelString or ""
  end
  return label
end

local function ingest(runtime, payload)
  local handled, conversation, meta = ChannelChatIngest.HandleEvent(runtime, payload)
  -- Unlike group chats, muting a channel silences mentions too.
  if meta and meta.mention and not conversation.muted then
    IncomingAlerts.Notify(runtime.accountState and runtime.accountState.settings)
  end
  -- Coalesced and keyed; the scheduler ignores lines while the window is hidden.
  if handled and conversation and type(runtime.scheduleIncomingRefresh) == "function" then
    runtime.scheduleIncomingRefresh(conversation.conversationKey)
  end
end

-- CHAT_MSG_CHANNEL arguments: 1 text, 2 playerName, 4 channelName,
-- 7 zoneChannelID, 8 channelIndex, 9 channelBaseName, 11 lineID, 12 guid.
function ChannelRouter.RouteChannelEvent(runtime, eventName, ...)
  if runtime == nil or eventName ~= EVENT_NAME then
    return nil
  end
  local text, playerName, _, channelName, _, _, zoneChannelID, channelIndex, channelBaseName, _, lineID, guid = ...
  local channelLabel = channelLabelFor(channelName)

  -- Ignored players and blocked lines are dropped everywhere, including the
  -- context kept for whisper chats. The player's own lines always pass.
  local isSelf = Direction.IsLocalSender(EVENT_NAME, guid, nil, runtime)
  if IncomingFilter.Evaluate(runtime, "channel", playerName, text, lineID, channelLabel, isSelf) ~= "pass" then
    return true
  end

  local store = runtime.channelMessageStore
  if store ~= nil then
    local sentAt = runtime.now and runtime.now() or 0
    ChannelMessageStore.Record(store, playerName, text, channelLabel, sentAt)
  end

  if not (runtime.isChannelIngestSuspended and runtime.isChannelIngestSuspended()) then
    ingest(runtime, {
      text = text,
      playerName = playerName,
      channelName = channelName,
      zoneChannelID = zoneChannelID,
      channelIndex = channelIndex,
      channelBaseName = channelBaseName,
      lineID = lineID,
      guid = guid,
    })
  end
  return store or true
end

ns.BootstrapEventBridgeChannelRouter = ChannelRouter
return ChannelRouter
