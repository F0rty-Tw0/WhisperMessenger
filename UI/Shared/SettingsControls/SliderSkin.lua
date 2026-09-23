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

-- The thumb's left edge travels 0..(width - thumb), so its centre sits at
-- thumb/2 + fraction * (width - thumb).
function SliderSkin.UpdateFill(skin)
  local slider = skin.slider
  local minValue, maxValue = slider:GetMinMaxValues()
  local range = maxValue - minValue
  local fraction = range > 0 and (slider:GetValue() - minValue) / range or 0
  fraction = math.max(0, math.min(1, fraction))
  local width = slider:GetWidth() or 0
  local knob = SliderSkin.THUMB_SIZE
  skin.fill:SetWidth(math.max(knob / 2, knob / 2 + fraction * (width - knob)))
end

function SliderSkin.Apply(skin, activeTheme)
  local colors = activeTheme.COLORS
  UIHelpers.applyColorTexture(skin.track, colors.slider_track)
  UIHelpers.applyColorTexture(skin.fill, colors.slider_fill)
  UIHelpers.applyVertexColor(skin.thumb, colors.control_knob)
  SliderSkin.UpdateFill(skin)
end

-- Value / range label colours: the value reads as primary (shown once,
-- top-right); the min/max labels stay faint.
function SliderSkin.LabelColors(activeTheme)
  return activeTheme.COLORS.text_primary, activeTheme.COLORS.text_timestamp
end

ns.SettingsControlsSliderSkin = SliderSkin
return SliderSkin
