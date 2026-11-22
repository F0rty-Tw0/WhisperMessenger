local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")

-- Hides the border pieces on the screen side and bottom of a window held
-- against a screen edge, stretches its backgrounds to those edges and paints a
-- dark shade there. One piece list per chrome (keys from the Blizzard
-- templates); a key a flavour lacks is skipped. Only pieces that were shown
-- are hidden and restored; the backgrounds get their own points back.
local ScreenEdgeBorder = {}

local SHADE_LEVEL_ABOVE_PANES = 25
local SHADE_COLOR = { 0, 0, 0, 0.75 }

-- BasicFrameTemplateWithInset: outer border, then the inset's border.
local CLASSIC_KEYS = {
  "TopLeftCorner",
  "TopRightCorner",
  "BotLeftCorner",
  "BotRightCorner",
  "BottomBorder",
  "InsetBorderBottom",
  "InsetBorderBottomLeft",
  "InsetBorderBottomRight",
  -- The inset's top row: InsetBg reaches the frame top, the title divider replaces it.
  "InsetBorderTop",
  "InsetBorderTopLeft",
  "InsetBorderTopRight",
  -- The title strip (also on ButtonFrameTemplate: TopTileStreaks).
  "TopBorder",
  "TitleBg",
  "TopTileStreaks",
}
local CLASSIC_SIDE_KEYS = {
  left = { "LeftBorder", "InsetBorderLeft", "InsetBorderTopLeft" },
  right = { "RightBorder", "InsetBorderRight", "InsetBorderTopRight" },
}
-- ButtonFrameTemplate's NineSlice.
local RETAIL_KEYS = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "BottomEdge", "TopEdge" }
local RETAIL_SIDE_KEYS = { left = { "LeftEdge" }, right = { "RightEdge" } }
-- The Retail panel insets (InsetFrameTemplate NineSlice): their top on the
-- inner side stays.
local INSET_KEYS = { "BottomLeftCorner", "BottomRightCorner", "BottomEdge" }
local INSET_SIDE_KEYS = { left = { "TopLeftCorner", "LeftEdge" }, right = { "TopRightCorner", "RightEdge" } }
local PANEL_INSETS = { "Inset", "contactsInset" }
local BACKGROUND_KEYS = { "Bg", "InsetBg" }
-- The side tile on the inner side, by screen side (Classic frame, Retail NineSlice).
local INNER_TILE_KEYS = { left = "RightBorder", right = "LeftBorder" }
local INNER_EDGE_KEYS = { left = "RightEdge", right = "LeftEdge" }
-- The inset's line on the inner side; its corners are hidden (CLASSIC_KEYS).
local INNER_INSET_KEYS = { left = "InsetBorderRight", right = "InsetBorderLeft" }
local CLOSE_INSET = 4

local function collect(pieces, owner, keys, sideKeys)
  if type(owner) ~= "table" then
    return
  end
  for _, key in ipairs(keys) do
    pieces[#pieces + 1] = owner[key]
  end
  for _, key in ipairs(sideKeys) do
    pieces[#pieces + 1] = owner[key]
  end
end

local function screenSidePieces(frame, windowEdges, side)
  local pieces = {}
  if type(windowEdges) == "table" then
    pieces[1], pieces[2], pieces[3] = windowEdges.top, windowEdges.bottom, windowEdges[side]
  end
  collect(pieces, frame, CLASSIC_KEYS, CLASSIC_SIDE_KEYS[side])
  collect(pieces, frame.NineSlice, RETAIL_KEYS, RETAIL_SIDE_KEYS[side])
  -- The portrait is the floating button's slot; at the edge the button stays
  -- home, so it goes with its ring (NineSlice.TopLeftCorner, above).
  pieces[#pieces + 1] = frame.PortraitContainer
  for _, key in ipairs(PANEL_INSETS) do
    collect(pieces, frame[key] and frame[key].NineSlice, INSET_KEYS, INSET_SIDE_KEYS[side])
  end
  return pieces
end

-- Moves the region's points that sit on the frame's screen side or bottom
-- onto that edge; returns its old points.
local function readPoints(region)
  local saved = {}
  for i = 1, region:GetNumPoints() do
    saved[i] = { region:GetPoint(i) }
  end
  return saved
end

local function stretch(region, frame, side)
  local saved = readPoints(region)
  local edge = side == "right" and "RIGHT" or "LEFT"
  region:ClearAllPoints()
  for _, p in ipairs(saved) do
    local x, y = p[4], p[5]
    if p[2] == frame and string.find(p[3], edge, 1, true) then
      x = 0
    end
    -- Top too: the title art is hidden, so the background fills the header.
    if p[2] == frame and (string.find(p[3], "BOTTOM", 1, true) or string.find(p[3], "TOP", 1, true)) then
      y = 0
    end
    region:SetPoint(p[1], p[2], p[3], x, y)
  end
  return saved
end

local function setPoints(region, points)
  region:ClearAllPoints()
  for _, p in ipairs(points) do
    region:SetPoint(p[1], p[2], p[3], p[4], p[5])
  end
end

-- The inner tile runs between its two (hidden) corners' outer ends instead
-- of their inner ends: frame top to frame bottom.
local function runFullHeight(region)
  local saved = readPoints(region)
  region:ClearAllPoints()
  for _, p in ipairs(saved) do
    region:SetPoint(p[1], p[2], p[1], p[4], 0)
  end
  return saved
end

-- The inner inset line on InsetBg's own edge, which reaches the frame top and
-- bottom while docked (stretch), instead of between its hidden corners.
local function runInsetFullHeight(region, frame)
  local saved = readPoints(region)
  region:ClearAllPoints()
  for _, p in ipairs(saved) do
    region:SetPoint(p[1], frame.InsetBg, p[1], 0, 0)
  end
  return saved
end

-- Centred in the docked title row, inside the frame.
local function moveCloseInside(button, frame)
  local saved = readPoints(button)
  button:ClearAllPoints()
  button:SetPoint("RIGHT", frame, "TOPRIGHT", -CLOSE_INSET, -Theme.LAYOUT.SCREEN_EDGE_TITLE_ROW_HEIGHT / 2)
  return saved
end

-- look (optional): titleHeight (px from the frame top to the divider under the
-- title row), hud (Native HUD colours).
function ScreenEdgeBorder.Create(factory, frame, windowEdges, look)
  look = look or {}
  local hiddenByUs = {}
  local movedPoints = {}
  local shade, shadeTexture
  local result = {}
  local dividerIsLine = false

  local function move(region, mover)
    if region and region.GetNumPoints and region:GetNumPoints() > 0 then
      movedPoints[region] = mover(region, frame)
    end
  end

  local function paintTitleDivider()
    if not look.titleHeight then
      return
    end
    local divider = result.titleDivider
    if not divider then
      divider = frame:CreateTexture(nil, "OVERLAY")
      divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -look.titleHeight)
      divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -look.titleHeight)
      result.titleDivider = divider
      -- Custom chrome, or a client without the atlas: a 1 px border line.
      dividerIsLine = not (look.hud and NativeArt.SetBevel(divider, NativeArt.INSET_TOP_BEVEL))
      if dividerIsLine then
        divider:SetHeight(1)
      end
    end
    if dividerIsLine then
      UIHelpers.applyColorTexture(divider, Theme.COLORS.window_border)
    end
    divider:Show()
  end

  local function restore()
    for _, piece in ipairs(hiddenByUs) do
      piece:Show()
    end
    hiddenByUs = {}
    for region, points in pairs(movedPoints) do
      setPoints(region, points)
    end
    movedPoints = {}
  end

  local function paintShade(side)
    if not shade then
      shade = factory.CreateFrame("Frame", nil, frame)
      shade:EnableMouse(false)
      shade:SetWidth(Theme.LAYOUT.SCREEN_EDGE_SHADE_WIDTH)
      shadeTexture = shade:CreateTexture(nil, "OVERLAY")
      shadeTexture:SetAllPoints(shade)
    end
    -- Every apply: the window may have been raised since.
    shade:SetFrameLevel(frame:GetFrameLevel() + SHADE_LEVEL_ABOVE_PANES)
    local edge = side == "right" and "RIGHT" or "LEFT"
    shade:ClearAllPoints()
    shade:SetPoint("TOP" .. edge, frame, "TOP" .. edge, 0, 0)
    shade:SetPoint("BOTTOM" .. edge, frame, "BOTTOM" .. edge, 0, 0)
    if side == "right" then
      UIHelpers.applyHorizontalFadeLeft(shadeTexture, SHADE_COLOR)
    else
      UIHelpers.applyHorizontalFade(shadeTexture, SHADE_COLOR)
    end
    shade:Show()
  end

  result.apply = function(side)
    restore()
    if side ~= "left" and side ~= "right" then
      if shade then
        shade:Hide()
      end
      if result.titleDivider then
        result.titleDivider:Hide()
      end
      return
    end
    for _, piece in ipairs(screenSidePieces(frame, windowEdges, side)) do
      if piece.IsShown and piece:IsShown() then
        piece:Hide()
        hiddenByUs[#hiddenByUs + 1] = piece
      end
    end
    for _, key in ipairs(BACKGROUND_KEYS) do
      local region = frame[key]
      if region and region.GetNumPoints then
        movedPoints[region] = stretch(region, frame, side)
      end
    end
    move(frame[INNER_TILE_KEYS[side]], runFullHeight)
    move(frame.NineSlice and frame.NineSlice[INNER_EDGE_KEYS[side]], runFullHeight)
    if frame.InsetBg then
      move(frame[INNER_INSET_KEYS[side]], runInsetFullHeight)
    end
    move(frame.CloseButton, moveCloseInside)
    paintTitleDivider()
    paintShade(side)
  end
  return result
end

ns.MessengerWindowChromeBuilderScreenEdgeBorder = ScreenEdgeBorder

return ScreenEdgeBorder
