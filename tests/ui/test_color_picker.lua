-- ColorPicker.Open: the game's colour picker through either API shape.
local ColorPicker = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ColorPicker")

local function withGlobals(globals, fn)
  local saved = {}
  for k, v in pairs(globals) do
    saved[k] = rawget(_G, k)
    rawset(_G, k, v)
  end
  local ok, err = pcall(fn)
  for k in pairs(globals) do
    rawset(_G, k, saved[k])
  end
  assert(ok, err)
end

local function newFrame(modern)
  local frame = { rgb = { 0, 0, 0 }, log = {} }
  function frame:GetColorRGB()
    return self.rgb[1], self.rgb[2], self.rgb[3]
  end
  if modern then
    function frame:SetupColorPickerAndShow(info)
      self.info = info
    end
  else
    function frame:SetColorRGB(r, g, b)
      self.rgb = { r, g, b }
      self.log[#self.log + 1] = { "SetColorRGB", self.func }
    end
  end
  return frame
end

return function()
  -- test_modern_shape_sets_up_and_shows_without_opacity
  do
    local frame = newFrame(true)
    local picked, cancelled = {}, 0
    withGlobals({ ColorPickerFrame = frame }, function()
      assert(ColorPicker.Open(0.1, 0.2, 0.3, function(r, g, b)
        picked[#picked + 1] = { r, g, b }
      end, function()
        cancelled = cancelled + 1
      end) == true, "opened")
    end)
    local info = frame.info
    assert(info.r == 0.1 and info.g == 0.2 and info.b == 0.3, "starts at the given colour")
    assert(not info.hasOpacity and info.opacityFunc == nil, "no opacity")
    frame.rgb = { 0.4, 0.5, 0.6 }
    info.swatchFunc()
    assert(#picked == 1 and picked[1][1] == 0.4 and picked[1][3] == 0.6, "a drag reports the picker colour")
    info.cancelFunc({ r = 0.1, g = 0.2, b = 0.3 })
    assert(cancelled == 1, "cancel reported")
  end

  -- test_old_shape_sets_fields_then_shows_the_panel
  do
    local frame = newFrame(false)
    local shown
    local picked, cancelled = {}, 0
    withGlobals({
      ColorPickerFrame = frame,
      ShowUIPanel = function(f)
        shown = f
      end,
    }, function()
      assert(ColorPicker.Open(0.1, 0.2, 0.3, function(r, g, b)
        picked[#picked + 1] = { r, g, b }
      end, function()
        cancelled = cancelled + 1
      end) == true, "opened")
    end)
    assert(shown == frame, "ShowUIPanel(ColorPickerFrame)")
    assert(frame.log[1][1] == "SetColorRGB" and frame.log[1][2] == nil, "the start colour is set before func, so it reports nothing")
    assert(frame.rgb[1] == 0.1 and frame.rgb[3] == 0.3, "starts at the given colour")
    assert(not frame.hasOpacity and frame.opacityFunc == nil, "no opacity")
    assert(frame.previousValues[1] == 0.1 and frame.previousValues[3] == 0.3, "previous values")
    frame.rgb = { 0.7, 0.8, 0.9 }
    frame.func()
    assert(#picked == 1 and picked[1][2] == 0.8, "a drag reports the picker colour")
    frame.cancelFunc(frame.previousValues)
    assert(cancelled == 1, "cancel reported")
  end

  -- test_no_picker_frame_opens_nothing
  do
    withGlobals({ ColorPickerFrame = false }, function()
      assert(ColorPicker.Open(0, 0, 0, function() end, function() end) == false, "nothing to open")
    end)
  end
end
