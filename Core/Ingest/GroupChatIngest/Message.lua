local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local Mention = ns.GroupChatIngestMention or require("WhisperMessenger.Core.Ingest.GroupChatIngest.Mention")

-- Builds the stored message for one group chat line.
local Message = {}

function Message.Build(payload, direction, channel, sentAt, isLeader)
  local playerInfo = payload.playerInfo or {}
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
    lineID = payload.lineID,
    guid = payload.guid,
    playerName = payload.playerName,
    channel = channel,
    bnetAccountID = payload.bnSenderID,
    className = playerInfo.className,
    classTag = playerInfo.classTag,
    senderClassTag = senderClassTag,
    senderName = senderName,
    raceName = playerInfo.raceName,
    raceTag = playerInfo.raceTag,
    factionName = playerInfo.factionName,
  }
  -- Only attach isLeader for PARTY/INSTANCE messages that have the concept
  if isLeader ~= nil then
    msg.isLeader = isLeader
  end
  if direction == "in" and Mention.Matches(payload.text, Mention.PlayerName()) then
    msg.mention = true
  end
  return msg
end

ns.GroupChatIngestMessage = Message
return Message
