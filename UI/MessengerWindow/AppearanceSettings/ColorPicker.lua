local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Opens the game's colour picker without opacity. onColor(r, g, b) runs on
-- every drag and on Okay; onCancel() on Cancel, Escape or a click outside.
local ColorPicker = {}

function ColorPicker.Open(r, g, b, onColor, onCancel)
  local frame = _G.ColorPickerFrame
  if not frame then
    return false
  end
  local function report()
    onColor(frame:GetColorRGB())
  end
  local function cancel()
    onCancel()
  end
  -- Retail and Forever (10.2.5+): the info table, as Blizzard's chat colour swatches call it.
  if type(frame.SetupColorPickerAndShow) == "function" then
    frame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = report, cancelFunc = cancel })
    return true
  end
  -- Older clients: fields on the frame. SetColorRGB fires func, so func goes on after it.
  frame.func, frame.opacityFunc, frame.cancelFunc = nil, nil, nil
  frame.hasOpacity = false
  frame.previousValues = { r, g, b }
  frame:SetColorRGB(r, g, b)
  frame.func, frame.cancelFunc = report, cancel
  _G.ShowUIPanel(frame)
  return true
end

function ColorPicker.IsOpen()
  local frame = _G.ColorPickerFrame
  return frame and frame:IsShown() == true or false
end

ns.AppearanceSettingsColorPicker = ColorPicker
return ColorPicker
