local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
local Constants = ns.Constants or require("WhisperMessenger.Core.Constants")
local GroupChatIngest = ns.GroupChatIngest or require("WhisperMessenger.Core.Ingest.GroupChatIngest")
local Trace = ns.trace or require("WhisperMessenger.Core.Trace")

local GroupRouter = {}

local GROUP_EVENTS = {}
for _, name in ipairs(Constants.GROUP_EVENT_NAMES) do
  GROUP_EVENTS[name] = true
end

-- TRACE_EVENTS is defined in the facade (EventBridge.lua) where RouteLiveEvent
-- also uses it. GroupRouter receives TRACE_EVENTS as a parameter to RouteGroupEvent
-- so neither module duplicates the constant nor couples to the other.
-- The caller (EventBridge facade) passes its local TRACE_EVENTS table.

-- Attempt to resolve a BN conversation ID by iterating known conversations
-- and matching on bnSenderID. Returns nil when not resolvable.
-- pcall-guarded: BNGetNumConversations may be absent on Classic flavors.
local function resolveBNConversationID(bnSenderID)
  if bnSenderID == nil then
    return nil
  end
  local ok, numConversations = pcall(function()
    return _G.BNGetNumConversations and _G.BNGetNumConversations() or 0
  end)
  if not ok or type(numConversations) ~= "number" or numConversations < 1 then
    return nil
  end
  for i = 1, numConversations do
    local convOk, conversationID = pcall(function()
      local id = _G.BNGetConversationInfo and _G.BNGetConversationInfo(i)
      return id
    end)
    if convOk and conversationID ~= nil then
      return conversationID
    end
  end
  return nil
end

-- Resolve (clubId, streamId, clubType) for the most recent community chat
-- line. Blizzard's API takes no args and returns info about the last message —
-- reliable inside a CHAT_MSG_COMMUNITIES_CHANNEL handler because the event
-- fires synchronously right after Blizzard records the line.
-- Returns nil, nil, nil when the API is absent or throws.
local function resolveCommunityChatSource()
  local clubApi = _G.C_Club
  if type(clubApi) ~= "table" or type(clubApi.GetInfoFromLastCommunityChatLine) ~= "function" then
    return nil, nil, nil
  end
  local ok, info = pcall(clubApi.GetInfoFromLastCommunityChatLine)
  if not ok or type(info) ~= "table" then
    return nil, nil, nil
  end
  return info.clubId, info.streamId, info.clubType
end

function GroupRouter.RouteGroupEvent(runtime, eventName, traceEvents, ...)
  if runtime == nil or not GROUP_EVENTS[eventName] then
    return false
  end

  -- Pull only the fields we use out of the 17-arg Blizzard group chat
  -- signature (text, sender, _, channel, _, _, _, _, channelBaseName, _,
  -- lineID, guid, bnSenderID, ...).
  local args = { ... }
  local text = args[1]
  local playerName = args[2]
  local channelName = args[4]
  local channelBaseName = args[9]
  local lineID = args[11]
  local guid = args[12]
  local bnSenderID = args[13]

  local conversationID = nil
  if eventName == "CHAT_MSG_BN_CONVERSATION" then
    conversationID = resolveBNConversationID(bnSenderID)
  end

  -- Community chat resolution. Skip guild-type clubs because they also fire
  -- CHAT_MSG_GUILD / CHAT_MSG_OFFICER which are already handled, and we do
  -- not want duplicate threads or messages.
  local clubId, streamId, streamName = nil, nil, nil
  if eventName == "CHAT_MSG_COMMUNITIES_CHANNEL" then
    local cId, sId, clubType = resolveCommunityChatSource()
    if cId == nil or sId == nil then
      return false
    end
    -- Enum.ClubType.Guild == 2. Deduped with CHAT_MSG_GUILD / CHAT_MSG_OFFICER.
    if clubType == 2 then
      return false
    end
    clubId = tostring(cId)
    streamId = tostring(sId)
    -- Prefer the bare stream base name over the full "Club: Stream" channelName.
    if type(channelBaseName) == "string" and channelBaseName ~= "" then
      streamName = channelBaseName
    elseif type(channelName) == "string" and channelName ~= "" then
      streamName = channelName
    end
  end

  -- Resolve sender class/race/faction from guid so the chat bubble can
  -- render a class icon and class-colored name. BN_CONVERSATION events
  -- don't carry a guid (BNet identity instead) — skip for that surface.
  local playerInfo = nil
  if guid and eventName ~= "CHAT_MSG_BN_CONVERSATION" then
    playerInfo = BNetResolver.ResolvePlayerInfo(runtime and runtime.playerInfoByGUID or nil, guid)
  end

  local payload = {
    text = text,
    playerName = playerName,
    lineID = lineID,
    guid = guid,
    bnSenderID = bnSenderID,
    conversationID = conversationID,
    clubId = clubId,
    streamId = streamId,
    streamName = streamName,
    playerInfo = playerInfo,
  }

  if Trace and traceEvents and traceEvents[eventName] then
    Trace("EventBridge: " .. eventName .. " from=" .. tostring(playerName) .. " guid=" .. tostring(guid) .. " lineID=" .. tostring(lineID))
  end

  local handled = GroupChatIngest.HandleEvent(runtime, eventName, payload)
  if handled and type(runtime.refreshWindow) == "function" then
    runtime.refreshWindow()
  end
  return handled
end

ns.BootstrapEventBridgeGroupRouter = GroupRouter

return GroupRouter
