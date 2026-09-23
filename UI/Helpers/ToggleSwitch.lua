local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Base = ns.UIHelpersBase or require("WhisperMessenger.UI.Helpers.Base")
local Shapes = ns.UIHelpersShapes or require("WhisperMessenger.UI.Helpers.Shapes")

-- Modern on/off switch: pill track (rounded background sized so the corner
-- radius is half the height) and a round knob that sits left when off and
-- right when on. Parts are created once per toggle; Paint only recolors,
-- re-anchors and toggles visibility.
local ToggleSwitch = {}

ToggleSwitch.TRACK_WIDTH = 28
ToggleSwitch.TRACK_HEIGHT = 16
ToggleSwitch.KNOB_SIZE = 12
ToggleSwitch.KNOB_INSET = 2
-- Same white disc the rounded-corner helper uses; tinted via vertex colour.
ToggleSwitch.KNOB_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall"

local function setShown(switch, shown)
  for _, part in ipairs(switch.track.fills) do
    part:SetShown(shown)
  end
  for _, part in ipairs(switch.track.corners) do
    part:SetShown(shown)
  end
  switch.knob:SetShown(shown)
end

function ToggleSwitch.Attach(button)
  local track = Shapes.createRoundedBackground(button, ToggleSwitch.TRACK_HEIGHT / 2, "BACKGROUND")
  local knob = button:CreateTexture(nil, "ARTWORK")
  knob:SetSize(ToggleSwitch.KNOB_SIZE, ToggleSwitch.KNOB_SIZE)
  knob:SetTexture(ToggleSwitch.KNOB_TEXTURE)
  return { track = track, knob = knob }
end

-- colors: { on, off, knob }
function ToggleSwitch.Paint(switch, button, enabled, colors)
  setShown(switch, true)
  switch.track.setColor(enabled and colors.on or colors.off)
  Base.applyVertexColor(switch.knob, colors.knob)
  switch.knob:ClearAllPoints()
  if enabled then
    switch.knob:SetPoint("RIGHT", button, "RIGHT", -ToggleSwitch.KNOB_INSET, 0)
  else
    switch.knob:SetPoint("LEFT", button, "LEFT", ToggleSwitch.KNOB_INSET, 0)
  end
end

ns.UIHelpersToggleSwitch = ToggleSwitch
return ToggleSwitch
