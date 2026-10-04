local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Which conversation a public channel line belongs to. Built-in channel
-- names are localized, so they key by zone channel ID; custom channels
-- (ID 0) key by their lowercased base name.
local ChannelKey = {}

ChannelKey.ZONE_CHANNEL_IDS = {
  [1] = "general",
  [2] = "trade",
  [22] = "localdefense",
  [23] = "worlddefense",
  [26] = "lfg",
  [42] = "tradeservices",
}

local CUSTOM_PREFIX = "c:"

-- "General - Stormwind City" -> "General"; names without a zone unchanged.
function ChannelKey.BaseName(channelBaseName)
  if type(channelBaseName) ~= "string" or channelBaseName == "" then
    return nil
  end
  return string.match(channelBaseName, "^(.-) %- ") or channelBaseName
end

-- The slug behind "CHANNEL::<slug>", or nil when the line names no channel.
function ChannelKey.Slug(zoneChannelID, channelBaseName)
  local builtIn = ChannelKey.ZONE_CHANNEL_IDS[zoneChannelID]
  if builtIn ~= nil then
    return builtIn
  end
  local baseName = ChannelKey.BaseName(channelBaseName)
  return baseName and (CUSTOM_PREFIX .. string.lower(baseName)) or nil
end

-- A non-zero zone channel ID missing from ZONE_CHANNEL_IDS: the line keys by
-- its (localized) name instead, so /wmsg perf counts these.
function ChannelKey.IsUnknownZoneID(zoneChannelID)
  return type(zoneChannelID) == "number" and zoneChannelID ~= 0 and ChannelKey.ZONE_CHANNEL_IDS[zoneChannelID] == nil
end

function ChannelKey.ContactKey(zoneChannelID, channelBaseName)
  local slug = ChannelKey.Slug(zoneChannelID, channelBaseName)
  return slug and ("CHANNEL::" .. slug) or nil
end

-- "1. General - Stormwind City" -> "Stormwind City"; nil without a zone part.
function ChannelKey.ZoneLabel(channelName)
  if type(channelName) ~= "string" then
    return nil
  end
  return string.match(channelName, " %- (.+)$")
end

-- The key in settings.enabledChannels.
function ChannelKey.SettingKey(slug)
  return slug
end

ns.ChannelChatIngestChannelKey = ChannelKey
return ChannelKey
