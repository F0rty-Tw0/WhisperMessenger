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

-- Creates the rounded fill and gloss sheen once (the fill follows the input
-- box's size) and returns { rounded, sheen, apply }; apply() repaints for the
-- active theme.
function ComposerSurface.Create(pane, box, border)
  local rounded = UIHelpers.createRoundedBackground(box, INPUT_RADIUS)
  local sheen = UIHelpers.createSheen(pane)

  local function apply()
    rounded.setColor(Theme.COLORS.bg_message_input or Theme.COLORS.bg_input)
    UIHelpers.applyBorderBoxColor(border, Theme.COLORS.divider)
    UIHelpers.setBorderEdgesShown(border, TOP_ONLY)
    UIHelpers.applySheen(sheen)
  end

  return { rounded = rounded, sheen = sheen, apply = apply }
end

-- Native WoW HUD single-line input border (the preview reply row; the
-- composer draws CreateInputBorder below). Retail HUD uses the search-box
-- atlases when the client has them; every other case uses the file art,
-- which ships with every flavor.
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

-- The input scroll template's own multi-line border (every flavor ships
-- these files): 8px corners, stretched edges and a filled middle, so it keeps
-- its weight at any height.
ComposerSurface.NATIVE_INPUT_BORDER = {
  topLeft = "Interface\\Common\\Common-Input-Border-TL",
  top = "Interface\\Common\\Common-Input-Border-T",
  topRight = "Interface\\Common\\Common-Input-Border-TR",
  left = "Interface\\Common\\Common-Input-Border-L",
  middle = "Interface\\Common\\Common-Input-Border-M",
  right = "Interface\\Common\\Common-Input-Border-R",
  bottomLeft = "Interface\\Common\\Common-Input-Border-BL",
  bottom = "Interface\\Common\\Common-Input-Border-B",
  bottomRight = "Interface\\Common\\Common-Input-Border-BR",
}
local INPUT_BORDER_CORNER = 8

local function stretch(piece, from, fromPoint, to, toPoint)
  piece:SetPoint("TOPLEFT", from, fromPoint, 0, 0)
  piece:SetPoint("BOTTOMRIGHT", to, toPoint, 0, 0)
end

-- Draws that border edge to edge on `box` (the template draws it 5px outside
-- its scroll frame; the box is the whole input rect). Returns the pieces.
function ComposerSurface.CreateInputBorder(box)
  local p = {}
  for key, path in pairs(ComposerSurface.NATIVE_INPUT_BORDER) do
    p[key] = box:CreateTexture(nil, "BACKGROUND")
    p[key]:SetTexture(path)
  end
  for key, anchor in pairs({ topLeft = "TOPLEFT", topRight = "TOPRIGHT", bottomLeft = "BOTTOMLEFT", bottomRight = "BOTTOMRIGHT" }) do
    p[key]:SetSize(INPUT_BORDER_CORNER, INPUT_BORDER_CORNER)
    p[key]:SetPoint(anchor, box, anchor, 0, 0)
  end
  stretch(p.top, p.topLeft, "TOPRIGHT", p.topRight, "BOTTOMLEFT")
  stretch(p.bottom, p.bottomLeft, "TOPRIGHT", p.bottomRight, "BOTTOMLEFT")
  stretch(p.left, p.topLeft, "BOTTOMLEFT", p.bottomLeft, "TOPRIGHT")
  stretch(p.right, p.topRight, "BOTTOMLEFT", p.bottomRight, "TOPRIGHT")
  stretch(p.middle, p.left, "TOPRIGHT", p.right, "BOTTOMLEFT")

  return p
end

-- Border on `box` (the input itself on a client without the template), text
-- colours on `input`. Returns { native, apply }; apply(placeholder) keeps the
-- Blizzard look on every theme refresh (transparent pane, no hairline, fixed
-- text colours).
function ComposerSurface.CreateNative(input, border, paneBg, box)
  ComposerSurface.CreateInputBorder(box)

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
