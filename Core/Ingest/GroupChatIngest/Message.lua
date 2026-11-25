local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local Mention = ns.GroupChatIngestMention or require("WhisperMessenger.Model.Mention")
local SenderLevel = ns.SenderLevel or require("WhisperMessenger.Model.SenderLevel")
local DisplayName = ns.DisplayName or require("WhisperMessenger.Util.DisplayName")
local SeenLevelEvents = ns.SeenLevelEvents or require("WhisperMessenger.Core.SeenLevelEvents")

-- Builds the stored message for one group chat line.
local Message = {}

-- Shared stand-in for a line without player info; only ever read.
local NO_PLAYER_INFO = {}

local function setIfPresent(message, field, value)
  if value ~= nil then
    message[field] = value
  end
end

function Message.Build(payload, direction, channel, sentAt, isLeader)
  local playerInfo = payload.playerInfo or NO_PLAYER_INFO
  local senderClassTag
  local senderName
  if direction == "out" then
    -- Freeze the sending character's class and name so the bubble icon and
    -- "You — <char>" label survive relogging. Prefer already-resolved fields
    -- from the payload over live API calls.
    senderClassTag = playerInfo.classTag or LocalPlayer.ClassTag()
    -- Use the live player's short name, not payload.playerName. Group chat
    -- events deliver "Name-Realm"; SenderLabel compares against the live
    -- UnitName("player") which is the short form, so we normalize here.
    senderName = LocalPlayer.Name()
  end
  local msg = {
    id = tostring(payload.lineID or sentAt),
    direction = direction,
    kind = "user",
    text = payload.text,
    sentAt = sentAt,
    channel = channel,
  }
  -- The optional fields go on one at a time: a table constructor reserves a
  -- slot for every field it names, nil or not, which doubled the table of
  -- every group line kept in the session.
  setIfPresent(msg, "lineID", payload.lineID)
  setIfPresent(msg, "guid", payload.guid)
  setIfPresent(msg, "playerName", payload.playerName)
  setIfPresent(msg, "bnetAccountID", payload.bnSenderID)
  setIfPresent(msg, "className", playerInfo.className)
  setIfPresent(msg, "classTag", playerInfo.classTag)
  setIfPresent(msg, "senderClassTag", senderClassTag)
  setIfPresent(msg, "senderName", senderName)
  setIfPresent(msg, "raceName", playerInfo.raceName)
  setIfPresent(msg, "raceTag", playerInfo.raceTag)
  setIfPresent(msg, "factionName", playerInfo.factionName)
  -- Only attach isLeader for PARTY/INSTANCE messages that have the concept
  if isLeader ~= nil then
    msg.isLeader = isLeader
  end
  if direction == "in" and Mention.Matches(payload.text, Mention.PlayerName()) then
    msg.mention = true
  end
  -- The level as best known when they spoke; a later /who reply can raise it
  -- (SenderLevelBackfill). Looked up only while levels are shown, so the
  -- off-by-default option costs nothing.
  if direction == "in" and payload.guid and DisplayName.ShowPlayerLevels() then
    msg.senderLevel = SenderLevel.Lookup(payload.guid, payload.playerName)
    SeenLevelEvents.Record(payload.guid, payload.playerName, msg.senderLevel)
  end
  return msg
end

ns.GroupChatIngestMessage = Message
return Message
