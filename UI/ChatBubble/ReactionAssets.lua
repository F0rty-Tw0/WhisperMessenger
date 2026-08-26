local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")

local ReactionAssets = {}
local KEYS = Protocol.REACTION_KEYS

local ATLAS_WIDTH = 1024
local ATLAS_HEIGHT = 256
local SLOT_SIZE = 72
local SLOT_OFFSET_X = 28
local SLOT_OFFSET_Y = 28
local SLOT_STRIDE_X = 112
local SLOT_STRIDE_Y = 128
local PICKER_COLUMNS = 9
local PICKER_ROWS = 2

local TEX_COORDS = {}
for index, key in ipairs(KEYS) do
  local slot = index - 1
  local column = slot % PICKER_COLUMNS
  local row = math.floor(slot / PICKER_COLUMNS)
  local left = SLOT_OFFSET_X + column * SLOT_STRIDE_X
  local top = SLOT_OFFSET_Y + row * SLOT_STRIDE_Y
  TEX_COORDS[key] = {
    left / ATLAS_WIDTH,
    (left + SLOT_SIZE) / ATLAS_WIDTH,
    top / ATLAS_HEIGHT,
    (top + SLOT_SIZE) / ATLAS_HEIGHT,
  }
end

function ReactionAssets.GetTexCoords(key)
  return TEX_COORDS[key]
end

function ReactionAssets.GetInlineTextureMarkup(key)
  local coords = ReactionAssets.GetTexCoords(key)
  if coords == nil then
    return nil
  end

  local textureWidth, textureHeight = ATLAS_WIDTH, ATLAS_HEIGHT
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
    columns = PICKER_COLUMNS,
    rows = PICKER_ROWS,
    frameWidth = buttonSize * PICKER_COLUMNS + 12,
    frameHeight = buttonSize * PICKER_ROWS + 34,
    copyWidth = buttonSize * PICKER_COLUMNS,
    copyOffsetY = -(buttonSize * PICKER_ROWS + 8),
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
