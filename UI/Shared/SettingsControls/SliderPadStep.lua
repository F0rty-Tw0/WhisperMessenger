local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Tags a settings slider so a controller can step it: slider._wmPadStep
-- (read by the gamepad wiring) moves the value one step, clamped to the
-- range. It sets the value like a script does, so the row's own
-- OnValueChanged rounds, relabels and saves it, as a drag does.
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

ns.SettingsControlsSliderPadStep = SliderPadStep

return SliderPadStep
