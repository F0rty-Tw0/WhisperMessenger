local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")

local ReactionAssets = {}
local KEYS = Protocol.REACTION_KEYS

local TEX_COORDS = {
  heart = { 28 / 512, 100 / 512, 28 / 256, 100 / 256 },
  thumbsup = { 156 / 512, 228 / 512, 28 / 256, 100 / 256 },
  laugh = { 284 / 512, 356 / 512, 28 / 256, 100 / 256 },
  wow = { 412 / 512, 484 / 512, 28 / 256, 100 / 256 },
  sad = { 28 / 512, 100 / 512, 156 / 256, 228 / 256 },
  angry = { 156 / 512, 228 / 512, 156 / 256, 228 / 256 },
  question = { 284 / 512, 356 / 512, 156 / 256, 228 / 256 },
  gg = { 412 / 512, 484 / 512, 156 / 256, 228 / 256 },
}

function ReactionAssets.GetTexCoords(key)
  return TEX_COORDS[key]
end

function ReactionAssets.GetInlineTextureMarkup(key)
  local coords = ReactionAssets.GetTexCoords(key)
  if coords == nil then
    return nil
  end

  local textureWidth, textureHeight = 512, 256
  local left = math.floor(coords[1] * textureWidth + 0.5)
  local right = math.floor(coords[2] * textureWidth + 0.5)
  local top = math.floor(coords[3] * textureHeight + 0.5)
  local bottom = math.floor(coords[4] * textureHeight + 0.5)
  local size = ReactionAssets.GetIconSize()
  return string.format(
    "|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t",
    ReactionAssets.TEXTURE,
    size,
    size,
    textureWidth,
    textureHeight,
    left,
    right,
    top,
    bottom
  )
end

function ReactionAssets.FormatTextForDisplay(text)
  return (tostring(text or ""):gsub(":([%a%d_]+):", function(key)
    return ReactionAssets.GetInlineTextureMarkup(key) or ":" .. key .. ":"
  end))
end
function ReactionAssets.GetIconSize()
  local size = tonumber(Fonts.GetFontSize and Fonts.GetFontSize()) or 12
  return math.max(9, math.min(17, size))
end
function ReactionAssets.GetPickerIconSize()
  return math.floor(ReactionAssets.GetIconSize() * 1.5 + 0.5)
end

function ReactionAssets.GetPickerLayout()
  local iconSize = ReactionAssets.GetPickerIconSize()
  local buttonSize = iconSize + 6
  return {
    iconSize = iconSize,
    buttonSize = buttonSize,
    frameWidth = buttonSize * #KEYS + 12,
    frameHeight = buttonSize + 34,
    copyWidth = buttonSize * #KEYS,
    copyOffsetY = -(buttonSize + 8),
  }
end
function ReactionAssets.GetBadgeOverflow()
  return math.max(0, ReactionAssets.GetIconSize() - ReactionAssets.BADGE_OFFSET_Y)
end

ReactionAssets.KEYS = KEYS
ReactionAssets.TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\reactions.png"
ReactionAssets.BADGE_OFFSET_Y = 7

ns.ChatBubbleReactionAssets = ReactionAssets
return ReactionAssets
