local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local PadButtons = ns.SettingsControlsPadButtons or require("WhisperMessenger.UI.Shared.SettingsControls.PadButtons")

-- Tags a settings slider so a controller can step it: slider._wmPadStep
-- moves the value one step, clamped to the range. It sets the value like a
-- script does, so the row's own OnValueChanged rounds, relabels and saves
-- it, as a drag does. The − / + pad buttons (AddButtons) call it.
local SliderPadStep = {}

function SliderPadStep.Attach(slider, min, max, step)
  slider._wmPadStep = function(delta)
    local current = slider:GetValue()
    local target = math.floor(current / step + 0.5) * step + delta * step
    target = math.max(min, math.min(max, target))
    if math.abs(target - current) < step / 2 then
      return
    end
    slider:SetValue(target)
  end
end

-- On a client with the gamepad UI API: a − button left of the slider and a
-- + button right of it, each one step. applyInset(inset) moves the slider
-- in by `inset` on both sides: the button size while the pad UI is on, 0
-- while it is off. Without the API: no buttons, applyInset never runs.
function SliderPadStep.AddButtons(factory, row, slider, applyInset)
  if not FlavorCompat.HasGamepadUI() then
    return
  end
  local minus = PadButtons.Create(factory, row, "minus", function()
    slider._wmPadStep(-1)
  end)
  minus:SetPoint("RIGHT", slider, "LEFT", -PadButtons.GAP, 0)
  local plus = PadButtons.Create(factory, row, "plus", function()
    slider._wmPadStep(1)
  end, function(shown)
    applyInset(shown and PadButtons.SIZE + PadButtons.GAP or 0)
  end)
  plus:SetPoint("LEFT", slider, "RIGHT", PadButtons.GAP, 0)
  -- The nav skips the slider, so spatial nav would leave the row for a
  -- nearer control above: link the pair across it.
  minus._wmPadJumps = { RIGHT = plus }
  plus._wmPadJumps = { LEFT = minus }
end

ns.SettingsControlsSliderPadStep = SliderPadStep

return SliderPadStep
