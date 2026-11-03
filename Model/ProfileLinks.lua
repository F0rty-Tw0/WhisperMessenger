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

-- Site slugs are ASCII: "Chants éternels" is chants-eternels. Each string
-- lists the two-byte UTF-8 letters that fold to its key.
local ACCENT_FOLDS = {
  a = "àáâãäåÀÁÂÃÄÅ",
  e = "èéêëÈÉÊË",
  i = "ìíîïÌÍÎÏ",
  o = "òóôõöÒÓÔÕÖ",
  u = "ùúûüÙÚÛÜ",
  c = "çÇ",
  n = "ñÑ",
  ss = "ß",
}
local UTF8_PAIR = "[\192-\223][\128-\191]"

local FOLD_BY_LETTER = {}
for ascii, letters in pairs(ACCENT_FOLDS) do
  for letter in string.gmatch(letters, UTF8_PAIR) do
    FOLD_BY_LETTER[letter] = ascii
  end
end

-- nil when a letter has no ASCII form (Cyrillic, Korean, Chinese realms).
local function asciiSlug(text)
  local folded = asciiLower((string.gsub(text, UTF8_PAIR, FOLD_BY_LETTER)))
  if string.find(folded, "[\128-\255]") then
    return nil
  end
  return folded
end

local function slugFromDisplay(displayRealm)
  local slug = asciiSlug(displayRealm)
  if slug == nil then
    return nil
  end
  slug = string.gsub(slug, "['%-%(%)]", "")
  slug = string.gsub(slug, "%s+", "-")
  return urlEncode(slug)
end

-- Returns slug, exact. The Armory needs the exact slug, which only the
-- display name gives: chat drops spaces, so even one word ("Templenoir") may
-- be two on the site (temple-noir).
function ProfileLinks.RealmSlug(character)
  if type(character.displayRealm) == "string" and character.displayRealm ~= "" then
    local slug = slugFromDisplay(character.displayRealm)
    return slug, slug ~= nil
  end
  local realm = character.realm
  if type(realm) ~= "string" or realm == "" then
    return nil, false
  end
  local slug = asciiSlug((string.gsub(realm, "'", "")))
  if slug == nil then
    return nil, false
  end
  return urlEncode(slug), false
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
