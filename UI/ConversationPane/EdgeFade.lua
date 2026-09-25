local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Soft top/bottom edges on the transcript: rows turn transparent as they
-- slide past the viewport edges instead of being cut with a hard line.
-- Fading the content (not painting over it) works on see-through themes.
-- The header and composer also cast a short dark shadow over the transcript
-- while messages are scrolled underneath them; nothing moves.
local EdgeFade = {}

local SHADOW_HEIGHT = 10
-- Dark, not the theme background, so it reads as a shadow on every theme.
local SHADOW_COLOR = { 0, 0, 0, 0.35 }
-- Above the scroll child, its bubbles and their badges.
local SHADOW_FRAME_LEVEL_LIFT = 20
-- Sub-pixel scroll leftovers still count as "at the edge".
local EDGE_TOLERANCE = 1

-- Short enough that the shortest row still rests fully opaque at scroll top
-- and at the end, where the content pad keeps it 8px inside the edge.
EdgeFade.FADE_DISTANCE = 24
local FADE_DISTANCE = EdgeFade.FADE_DISTANCE

local function clampAlpha(value)
  return math.max(0, math.min(value / FADE_DISTANCE, 1))
end

local function createShadow(overlay, point)
  local texture = overlay:CreateTexture(nil, "OVERLAY")
  texture:SetPoint(point .. "LEFT", overlay, point .. "LEFT", 0, 0)
  texture:SetPoint(point .. "RIGHT", overlay, point .. "RIGHT", 0, 0)
  texture:SetHeight(SHADOW_HEIGHT)
  return texture
end

-- Full pane width, viewport height: the shadows hang off the header line and
-- sit on the composer line without shortening the transcript.
local function createShadowOverlay(factory, parent, view)
  local overlay = factory.CreateFrame("Frame", nil, parent)
  overlay:SetPoint("TOP", view.scrollFrame, "TOP", 0, 0)
  overlay:SetPoint("BOTTOM", view.scrollFrame, "BOTTOM", 0, 0)
  overlay:SetPoint("LEFT", parent, "LEFT", 0, 0)
  overlay:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
  if overlay.SetFrameLevel and view.scrollFrame.GetFrameLevel then
    overlay:SetFrameLevel(view.scrollFrame:GetFrameLevel() + SHADOW_FRAME_LEVEL_LIFT)
  end
  return overlay
end

local function fadeRows(view)
  local state = view._virtualState
  local active = view.content and view.content._activeFrames
  if state == nil or active == nil or state.firstIndex == nil then
    return
  end
  local offset = ScrollView.GetOffset(view)
  local viewportHeight = view.viewportHeight or 0
  for index = state.firstIndex, state.lastIndex do
    local row = state.rows[index]
    if row and row.frameFirst then
      local rowTop = row.offset - offset
      local alpha = math.min(clampAlpha(rowTop + row.height), clampAlpha(viewportHeight - rowTop))
      for frameIndex = row.frameFirst, row.frameLast do
        local frame = active[frameIndex]
        if frame and frame.SetAlpha then
          frame:SetAlpha(alpha)
        end
      end
    end
  end
end

function EdgeFade.Attach(factory, parent, view)
  local overlay = createShadowOverlay(factory, parent, view)
  local fade = {
    topShadow = createShadow(overlay, "TOP"),
    bottomShadow = createShadow(overlay, "BOTTOM"),
  }
  -- Darkest against the header / composer line, fading into the transcript.
  UIHelpers.applyVerticalFade(fade.topShadow, SHADOW_COLOR)
  UIHelpers.applyVerticalFadeDown(fade.bottomShadow, SHADOW_COLOR)

  function fade.update()
    fadeRows(view)
    local offset = ScrollView.GetOffset(view)
    fade.topShadow:SetShown(offset > EDGE_TOLERANCE)
    fade.bottomShadow:SetShown(offset < ScrollView.GetRange(view) - EDGE_TOLERANCE)
  end

  -- The shadow is theme-independent, so a theme change needs no repaint.
  function fade.refreshTheme() end

  view.onPositionChanged = fade.update
  fade.update()
  return fade
end

ns.ConversationPaneEdgeFade = EdgeFade
return EdgeFade
