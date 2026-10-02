local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- Slider look: thin neutral track, accent fill from the min end to the thumb
-- centre, small round thumb. Textures are created once; the fill is resized
-- only on value changes and resizes (no OnUpdate).
local SliderSkin = {}

SliderSkin.TRACK_HEIGHT = 4
SliderSkin.THUMB_SIZE = 12
-- White disc (same one the rounded-corner helper uses); tinted per theme.
SliderSkin.CIRCLE_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall"

function SliderSkin.Attach(slider, track)
  track:ClearAllPoints()
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  track:SetHeight(SliderSkin.TRACK_HEIGHT)
  local fill = slider:CreateTexture(nil, "BORDER")
  fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
  fill:SetHeight(SliderSkin.TRACK_HEIGHT)
  fill:Show()
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(SliderSkin.CIRCLE_TEXTURE)
  thumb:SetSize(SliderSkin.THUMB_SIZE, SliderSkin.THUMB_SIZE)
  if slider.SetThumbTexture then
    slider:SetThumbTexture(thumb)
  end
  return { slider = slider, track = track, fill = fill, thumb = thumb }
end

-- Native WoW HUD: the template draws track and thumb. The skin only knows
-- the thumb width, so BlockTrackClicks still fits around it.
function SliderSkin.AttachNative(slider, thumbSize)
  return { slider = slider, thumbSize = thumbSize, native = true }
end

-- The thumb's left edge travels 0..(width - thumb), so its centre sits at
-- thumb/2 + fraction * (width - thumb).
function SliderSkin.UpdateFill(skin)
  local slider = skin.slider
  local minValue, maxValue = slider:GetMinMaxValues()
  local range = maxValue - minValue
  local fraction = range > 0 and (slider:GetValue() - minValue) / range or 0
  fraction = math.max(0, math.min(1, fraction))
  local knob = skin.thumbSize or SliderSkin.THUMB_SIZE
  local travel = math.max(0, (slider:GetWidth() or 0) - knob)
  local thumbLeft = fraction * travel
  if skin.fill then
    skin.fill:SetWidth(knob / 2 + thumbLeft)
  end
  if skin.leftBlocker then
    skin.leftBlocker:SetWidth(thumbLeft)
    skin.rightBlocker:SetWidth(travel - thumbLeft)
  end
end

-- Invisible mouse-catching strips on both sides of the thumb. A click on the
-- bare track lands on a strip instead of the slider, so only dragging the
-- thumb changes the value (the native slider jumps to the click point).
function SliderSkin.BlockTrackClicks(skin, factory)
  local slider = skin.slider
  local function strip(side)
    local frame = factory.CreateFrame("Frame", nil, slider)
    frame:SetPoint("TOP" .. side, slider, "TOP" .. side, 0, 0)
    frame:SetPoint("BOTTOM" .. side, slider, "BOTTOM" .. side, 0, 0)
    frame:SetFrameLevel(slider:GetFrameLevel() + 1)
    frame:EnableMouse(true)
    return frame
  end
  skin.leftBlocker = strip("LEFT")
  skin.rightBlocker = strip("RIGHT")
  SliderSkin.UpdateFill(skin)
end

-- The native skin has no textures to colour; it only re-fits the blockers.
function SliderSkin.Apply(skin, activeTheme)
  if not skin.native then
    local colors = activeTheme.COLORS
    UIHelpers.applyColorTexture(skin.track, colors.slider_track)
    UIHelpers.applyColorTexture(skin.fill, colors.slider_fill)
    UIHelpers.applyVertexColor(skin.thumb, colors.control_knob)
  end
  SliderSkin.UpdateFill(skin)
end

-- Value / range label colours: the value reads as primary (shown once,
-- top-right); the min/max labels stay faint.
function SliderSkin.LabelColors(activeTheme)
  return activeTheme.COLORS.text_primary, activeTheme.COLORS.text_timestamp
end

ns.SettingsControlsSliderSkin = SliderSkin
return SliderSkin
