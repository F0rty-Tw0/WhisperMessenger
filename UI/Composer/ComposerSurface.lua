local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

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

-- Native WoW HUD: Blizzard InputBoxTemplate border art drawn on the existing
-- composer EditBox (re-templating it would replace its scripts and insets).
-- The texture ships with every flavor, so no atlas lookup is needed.
ComposerSurface.NATIVE_BORDER_TEXTURE = "Interface\\Common\\Common-Input-Border"
local NATIVE_EDGE_WIDTH = 8
local NATIVE_TEXT_COLOR = { 1, 1, 1, 1 }
local NATIVE_PLACEHOLDER_COLOR = { 0.5, 0.5, 0.5, 1 }
local NO_EDGES = {}

local function borderPiece(input, left, right)
  local piece = input:CreateTexture(nil, "BACKGROUND")
  piece:SetTexture(ComposerSurface.NATIVE_BORDER_TEXTURE)
  piece:SetTexCoord(left, right, 0, 0.625)
  return piece
end

-- Returns { native, apply }; apply(placeholder) keeps the Blizzard look on
-- every theme refresh (transparent pane, no hairline, fixed text colours).
function ComposerSurface.CreateNative(input, border, paneBg)
  local left = borderPiece(input, 0, 0.0625)
  left:SetWidth(NATIVE_EDGE_WIDTH)
  left:SetPoint("TOPLEFT", input, "TOPLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", input, "BOTTOMLEFT", 0, 0)
  local right = borderPiece(input, 0.9375, 1)
  right:SetWidth(NATIVE_EDGE_WIDTH)
  right:SetPoint("TOPRIGHT", input, "TOPRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", input, "BOTTOMRIGHT", 0, 0)
  local middle = borderPiece(input, 0.0625, 0.9375)
  middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
  middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)

  local function apply(placeholder)
    UIHelpers.applyColorTexture(paneBg, UIHelpers.TRANSPARENT)
    UIHelpers.setBorderEdgesShown(border, NO_EDGES)
    UIHelpers.setTextColor(input, NATIVE_TEXT_COLOR)
    if placeholder then
      UIHelpers.setTextColor(placeholder, NATIVE_PLACEHOLDER_COLOR)
    end
  end

  return { native = true, apply = apply }
end

ns.ComposerSurface = ComposerSurface
return ComposerSurface
