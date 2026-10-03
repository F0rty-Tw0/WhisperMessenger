local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelKey = ns.ChannelChatIngestChannelKey or require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")

-- The live number of a joined chat channel. Numbers follow join order and
-- change when the player leaves or rejoins channels, so a channel chat looks
-- its number up by name at send time and never trusts a stored one.
local ChannelIndex = {}

local lower = string.lower
local select = select

local function sameChannel(name, wanted)
  local baseName = ChannelKey.BaseName(name)
  return baseName ~= nil and lower(baseName) == wanted
end

-- GetChannelList returns id, name, disabled triples. A disabled channel
-- (Trade outside a city) cannot be sent to.
local function findInList(wanted, ...)
  for index = 1, select("#", ...), 3 do
    local id, name, disabled = select(index, ...)
    if disabled ~= true and type(id) == "number" and sameChannel(name, wanted) then
      return id
    end
  end
  return nil
end

local function fromList(wanted)
  local ok, id = pcall(function()
    return findInList(wanted, _G.GetChannelList())
  end)
  return ok and id or nil
end

local function fromName(baseName)
  local ok, id = pcall(_G.GetChannelName, baseName)
  if ok and type(id) == "number" and id > 0 then
    return id
  end
  return nil
end

-- channelBaseName: the stored base name, possibly with a zone suffix
-- ("General - Elwynn Forest"). Returns the live channel number or nil.
function ChannelIndex.Resolve(channelBaseName)
  local baseName = ChannelKey.BaseName(channelBaseName)
  if baseName == nil then
    return nil
  end
  if type(_G.GetChannelList) == "function" then
    return fromList(lower(baseName))
  end
  if type(_G.GetChannelName) == "function" then
    return fromName(baseName)
  end
  return nil
end

ns.ChannelIndex = ChannelIndex
return ChannelIndex
