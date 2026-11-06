local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Text from a group chat addon message never passed the game's chat
-- checks, so it is cleaned before it is stored or drawn: game links
-- (items, spells, achievements, ...) stay clickable; textures, atlases,
-- colors, protected name tokens and any other escape code become plain
-- text, and control characters go.
local SafeText = {}

local gsub = string.gsub

local ALLOWED_LINK_TYPES = {
  achievement = true,
  battlepet = true,
  battlePetAbil = true,
  currency = true,
  enchant = true,
  instancelock = true,
  item = true,
  journal = true,
  keystone = true,
  mount = true,
  quest = true,
  spell = true,
  talent = true,
  trade = true,
  transmogappearance = true,
  transmogillusion = true,
  transmogset = true,
  worldmap = true,
}

local PIPE_PLACEHOLDER = "\1"
local LINK_OPEN = "\2"
local LINK_CLOSE = "\3"

function SafeText.Clean(text)
  if type(text) ~= "string" then
    return nil
  end
  -- Control bytes first, so the placeholders below cannot be forged.
  local clean = gsub(text, "[%c]", "")
  clean = gsub(clean, "||", PIPE_PLACEHOLDER)

  local links = {}
  local function keepLink(link, linkType)
    if not ALLOWED_LINK_TYPES[linkType] then
      return nil
    end
    links[#links + 1] = link
    return LINK_OPEN .. #links .. LINK_CLOSE
  end
  clean = gsub(clean, "(|c[^|]*|H(%a+):[^|]*|h%[[^|%]]*%]|h|r)", keepLink)
  clean = gsub(clean, "(|H(%a+):[^|]*|h%[[^|%]]*%]|h)", keepLink)

  clean = gsub(clean, "|T.-|t", "")
  clean = gsub(clean, "|A.-|a", "")
  clean = gsub(clean, "|K.-|k", "")
  clean = gsub(clean, "|H.-|h(.-)|h", "%1")
  clean = gsub(clean, "|c%x%x%x%x%x%x%x%x", "")
  clean = gsub(clean, "|cn[^:|]*:", "")
  clean = gsub(clean, "|r", "")
  -- Whatever escape is left shows as the characters typed.
  clean = gsub(clean, "|", "||")

  clean = gsub(clean, LINK_OPEN .. "(%d+)" .. LINK_CLOSE, function(index)
    return links[tonumber(index)]
  end)
  clean = gsub(clean, PIPE_PLACEHOLDER, "||")
  if string.match(clean, "^%s*$") then
    return nil
  end
  return clean
end

ns.GroupChatProtocolSafeText = SafeText
return SafeText
