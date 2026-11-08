local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")

-- Composer surfaces: a single hairline above the composer and a softly
-- filled rounded input with no border.
local ComposerSurface = {}

local TOP_ONLY = { top = true }
local INPUT_RADIUS = 8

-- Creates the rounded fill and gloss sheen once (the fill follows the input's
-- size) and returns { rounded, sheen, apply }; apply() repaints for the
-- active theme.
function ComposerSurface.Create(pane, input, border)
  local rounded = UIHelpers.createRoundedBackground(input, INPUT_RADIUS)
  local sheen = UIHelpers.createSheen(pane)

  local function apply()
    rounded.setColor(Theme.COLORS.bg_message_input or Theme.COLORS.bg_input)
    UIHelpers.applyBorderBoxColor(border, Theme.COLORS.divider)
    UIHelpers.setBorderEdgesShown(border, TOP_ONLY)
    UIHelpers.applySheen(sheen)
  end

  return { rounded = rounded, sheen = sheen, apply = apply }
end

-- Native WoW HUD: Blizzard input-box border art drawn on the existing
-- composer EditBox (re-templating it would replace its scripts and insets).
-- Retail HUD uses the search-box atlases when the client has them; every
-- other case uses the file art, which ships with every flavor.
ComposerSurface.NATIVE_BORDER_TEXTURE = "Interface\\Common\\Common-Input-Border"
ComposerSurface.NATIVE_SEARCH_ATLAS = {
  left = "common-search-border-left",
  middle = "common-search-border-middle",
  right = "common-search-border-right",
}
ComposerSurface.NATIVE_TEXT_COLOR = { 1, 1, 1, 1 }
ComposerSurface.NATIVE_PLACEHOLDER_COLOR = { 0.5, 0.5, 0.5, 1 }
local NATIVE_EDGE_WIDTH = 8
local NO_EDGES = {}

local function useSearchAtlases(leftPiece)
  return Hud.IsRetail() and NativeArt.AtlasInfo(ComposerSurface.NATIVE_SEARCH_ATLAS.left) ~= nil and type(leftPiece.SetAtlas) == "function"
end

-- Draws the three border pieces on `input` (full height, 8px edges, stretched
-- middle). The art is picked once for all three, never mixed. Returns
-- { left, middle, right }.
function ComposerSurface.CreateNativeBorder(input)
  local left = input:CreateTexture(nil, "BACKGROUND")
  local middle = input:CreateTexture(nil, "BACKGROUND")
  local right = input:CreateTexture(nil, "BACKGROUND")
  if useSearchAtlases(left) then
    local atlas = ComposerSurface.NATIVE_SEARCH_ATLAS
    NativeArt.SetAtlas(left, atlas.left, false)
    NativeArt.SetAtlas(middle, atlas.middle, false)
    NativeArt.SetAtlas(right, atlas.right, false)
  else
    for piece, coords in pairs({ [left] = { 0, 0.0625 }, [middle] = { 0.0625, 0.9375 }, [right] = { 0.9375, 1 } }) do
      piece:SetTexture(ComposerSurface.NATIVE_BORDER_TEXTURE)
      piece:SetTexCoord(coords[1], coords[2], 0, 0.625)
    end
  end
  left:SetWidth(NATIVE_EDGE_WIDTH)
  left:SetPoint("TOPLEFT", input, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", input, "BOTTOMLEFT", 0, 0)
  right:SetWidth(NATIVE_EDGE_WIDTH)
  right:SetPoint("TOPRIGHT", input, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", input, "BOTTOMRIGHT", 0, 0)
  middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
  middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
  return { left = left, middle = middle, right = right }
end

-- Returns { native, apply }; apply(placeholder) keeps the Blizzard look on
-- every theme refresh (transparent pane, no hairline, fixed text colours).
function ComposerSurface.CreateNative(input, border, paneBg)
  ComposerSurface.CreateNativeBorder(input)

  local function apply(placeholder)
    UIHelpers.applyColorTexture(paneBg, UIHelpers.TRANSPARENT)
    UIHelpers.setBorderEdgesShown(border, NO_EDGES)
    UIHelpers.setTextColor(input, ComposerSurface.NATIVE_TEXT_COLOR)
    if placeholder then
      UIHelpers.setTextColor(placeholder, ComposerSurface.NATIVE_PLACEHOLDER_COLOR)
    end
  end

  return { native = true, apply = apply }
end

ns.ComposerSurface = ComposerSurface
return ComposerSurface
