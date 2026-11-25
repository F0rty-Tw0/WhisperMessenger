local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")

-- The band at the bottom of a window held at a screen edge that the tab strip
-- sits in: the window background darkened, a divider along its top that the
-- tabs hang from, and room below them so the tab art is never cut by the screen.
local ScreenEdgeTabBand = {}

local DARKEN = { 0, 0, 0, 0.5 }

-- look: hud (Native HUD divider: the inset bottom bevel; else, or on a client
-- without that atlas, a 1 px window border line).
function ScreenEdgeTabBand.Create(factory, frame, look)
  local L = Theme.LAYOUT
  local band = factory.CreateFrame("Frame", nil, frame)
  band:EnableMouse(false)
  band:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  band:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  band:Hide()
  local fill = band:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(band)
  local divider = band:CreateTexture(nil, "BORDER")
  divider:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
  divider:SetPoint("TOPRIGHT", band, "TOPRIGHT", 0, 0)
  local dividerIsLine = not (look.hud and NativeArt.SetBevel(divider, NativeArt.INSET_BOTTOM_BEVEL))
  if dividerIsLine then
    divider:SetHeight(1)
  end
  divider:Show()

  return {
    frame = band,
    fill = fill,
    divider = divider,
    -- Shows the band around a strip this tall whose top hangs from the
    -- divider's bottom, tucked overlap px up under it; returns the band's height.
    show = function(stripHeight, overlap)
      local dividerHeight = dividerIsLine and 1 or L.SCREEN_EDGE_DIVIDER_HEIGHT
      local height = dividerHeight - (overlap or 0) + stripHeight + L.SCREEN_EDGE_TAB_BAND_PAD_BOTTOM
      band:SetHeight(height)
      UIHelpers.applyColorTexture(fill, DARKEN)
      if dividerIsLine then
        UIHelpers.applyColorTexture(divider, Theme.COLORS.window_border)
      end
      band:Show()
      return height
    end,
    hide = function()
      band:Hide()
    end,
  }
end

ns.MessengerWindowChromeBuilderScreenEdgeTabBand = ScreenEdgeTabBand

return ScreenEdgeTabBand
