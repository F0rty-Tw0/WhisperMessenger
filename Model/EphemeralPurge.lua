local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelType = ns.ChannelType
  or (type(require) == "function" and require("WhisperMessenger.Model.Identity.ChannelType"))
  or nil

local EphemeralPurge = {}

-- Only channels explicitly listed here are treated as ephemeral. Anything else
-- — nil, legacy "WOW"/"BN" strings, WHISPER/BN_WHISPER/BN_CONVERSATION/GUILD/
-- OFFICER/CHANNEL/COMMUNITY, or any future value we don't yet know about — is
-- kept. Defensive: an unknown channel string must never cause data loss.
local KNOWN_EPHEMERAL_CHANNELS = {
  [ChannelType.PARTY] = true,
  [ChannelType.RAID] = true,
  [ChannelType.INSTANCE_CHAT] = true,
}

-- PurgeAll removes every known-ephemeral conversation from state.conversations.
-- Conversations with any other channel value (including nil, "WOW", "BN", or
-- persistent channel types) are kept.
-- Returns the count of removed conversations.
function EphemeralPurge.PurgeAll(state)
  if state == nil or state.conversations == nil then
    return 0
  end

  local removed = 0
  local keysToRemove = {}

  for key, conv in pairs(state.conversations) do
    if KNOWN_EPHEMERAL_CHANNELS[conv.channel] then
      keysToRemove[#keysToRemove + 1] = key
    end
  end

  for i = 1, #keysToRemove do
    local key = keysToRemove[i]
    state.conversations[key] = nil
    if state.activeConversationKey == key then
      state.activeConversationKey = nil
    end
    removed = removed + 1
  end

  return removed
end

-- PurgeByChannel removes conversations whose channel is in the given channelSet.
-- channelSet is a table of the form { [ChannelType.PARTY] = true, ... }.
-- Returns the count of removed conversations.
function EphemeralPurge.PurgeByChannel(state, channelSet)
  if state == nil or state.conversations == nil then
    return 0
  end

  local removed = 0
  local keysToRemove = {}

  for key, conv in pairs(state.conversations) do
    if conv.channel ~= nil and channelSet[conv.channel] then
      keysToRemove[#keysToRemove + 1] = key
    end
  end

  for i = 1, #keysToRemove do
    local key = keysToRemove[i]
    state.conversations[key] = nil
    if state.activeConversationKey == key then
      state.activeConversationKey = nil
    end
    removed = removed + 1
  end

  return removed
end

ns.EphemeralPurge = EphemeralPurge
return EphemeralPurge
