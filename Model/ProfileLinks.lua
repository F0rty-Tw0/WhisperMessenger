local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Profile site URLs (Raider.IO, Warcraft Logs, Armory) for one character.
-- character: { name, realm (chat form, no spaces), displayRealm (optional) }.
-- game: { regionId (GetCurrentRegion), projectId (WOW_PROJECT_ID), isForever }.
local ProfileLinks = {}

local REGION_CODES = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw" }

local PROJECT_RETAIL = 1

-- Warcraft Logs runs one site per game: Era on vanilla, TBC Anniversary on
-- fresh, the progression Classic flavors on classic.
local WARCRAFT_LOGS_HOSTS = {
  [1] = "www",
  [2] = "vanilla",
  [5] = "fresh",
  [11] = "classic",
  [14] = "classic",
  [19] = "classic",
}

local function urlEncode(text)
  return (string.gsub(text, "[^A-Za-z0-9%-%._~]", function(char)
    return string.format("%%%02X", string.byte(char))
  end))
end

-- string.lower can follow the C locale and change UTF-8 bytes; only A-Z may
-- change.
local function asciiLower(text)
  return (string.gsub(text, "[A-Z]", string.lower))
end

local function slugFromDisplay(displayRealm)
  local slug = asciiLower(displayRealm)
  slug = string.gsub(slug, "['%-%(%)]", "")
  slug = string.gsub(slug, "%s+", "-")
  return urlEncode(slug)
end

-- Returns slug, exact. The Armory needs the exact slug; a chat realm only
-- gives one when it is a single word ("Kazzak").
function ProfileLinks.RealmSlug(character)
  if type(character.displayRealm) == "string" and character.displayRealm ~= "" then
    return slugFromDisplay(character.displayRealm), true
  end
  local realm = character.realm
  if type(realm) ~= "string" or realm == "" then
    return nil, false
  end
  local exact = string.find(realm, "^[A-Z][a-z]*$") ~= nil
  return urlEncode(asciiLower((string.gsub(realm, "'", "")))), exact
end

local function link(label, url)
  return { label = label, url = url }
end

function ProfileLinks.Build(character, game)
  local links = {}
  local region = REGION_CODES[game.regionId]
  if game.isForever or region == nil or type(character.name) ~= "string" or character.name == "" then
    return links
  end
  local slug, exact = ProfileLinks.RealmSlug(character)
  if slug == nil then
    return links
  end
  local path = region .. "/" .. slug .. "/"
  local lowerName = urlEncode(asciiLower(character.name))
  local isRetail = game.projectId == PROJECT_RETAIL

  if isRetail then
    links[#links + 1] = link("Raider.IO", "https://raider.io/characters/" .. path .. urlEncode(character.name))
  end
  local logsHost = WARCRAFT_LOGS_HOSTS[game.projectId]
  if logsHost ~= nil then
    links[#links + 1] = link("Warcraft Logs", "https://" .. logsHost .. ".warcraftlogs.com/character/" .. path .. lowerName)
  end
  if isRetail and exact then
    links[#links + 1] = link("Armory", "https://worldofwarcraft.blizzard.com/en-us/character/" .. path .. lowerName)
  end
  return links
end

ns.ProfileLinks = ProfileLinks
return ProfileLinks
