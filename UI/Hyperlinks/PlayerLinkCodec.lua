local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Player links shown in our frames are rewritten as addon links, so the
-- secure link template's SetItemRef ignores them (no /who on a shift-click)
-- and our click hook decodes and routes them instead, which then runs
-- Blizzard's player-link handler from addon code. The encoded form keeps the
-- whole original body:
-- player:Name-Realm:12 -> addon:WhisperMessenger:player:Name-Realm:12.
-- BNplayer and other link types, URL links included, are left alone.
local PlayerLinkCodec = {}

local PREFIX = "addon:WhisperMessenger:"
local PREFIX_LENGTH = string.len(PREFIX)
local PLAYER_BODY_PATTERN = "^player%a*:"

function PlayerLinkCodec.Encode(text)
  if type(text) ~= "string" then
    return text
  end
  return (string.gsub(text, "|Hplayer(%a*):", "|H" .. PREFIX .. "player%1:"))
end

function PlayerLinkCodec.IsEncoded(link)
  if type(link) ~= "string" or string.sub(link, 1, PREFIX_LENGTH) ~= PREFIX then
    return false
  end
  return string.match(string.sub(link, PREFIX_LENGTH + 1), PLAYER_BODY_PATTERN) ~= nil
end

function PlayerLinkCodec.DecodeLink(link)
  if not PlayerLinkCodec.IsEncoded(link) then
    return link
  end
  return string.sub(link, PREFIX_LENGTH + 1)
end

function PlayerLinkCodec.DecodeText(text)
  if type(text) ~= "string" then
    return text
  end
  return (string.gsub(text, "|H" .. PREFIX .. "(player%a*:)", "|H%1"))
end

ns.UIHyperlinksPlayerLinkCodec = PlayerLinkCodec
return PlayerLinkCodec
