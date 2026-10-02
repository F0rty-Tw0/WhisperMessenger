local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Base = ns.UIHelpersBase or require("WhisperMessenger.UI.Helpers.Base")

-- Native WoW HUD settings controls, built from Blizzard templates. Each
-- returns nil when the client lacks the template, so the caller falls back
-- to its modern widget. Template child keys differ between flavors, so
-- every one is optional.
local NativeControls = {}

NativeControls.CHECK_TEMPLATE = "UICheckButtonTemplate"
NativeControls.CHECK_SIZE = 26
NativeControls.BUTTON_TEMPLATE = "UIPanelButtonTemplate"
NativeControls.SLIDER_TEMPLATE = "OptionsSliderTemplate"
-- OptionsSliderTemplate's thumb art width, for clients that can't report it.
NativeControls.SLIDER_THUMB_SIZE = 32

local function hideChild(frame, key)
  local child = frame[key]
  if type(child) == "table" and type(child.Hide) == "function" then
    child:Hide()
  end
end

-- Our own label sits beside the box, so the template's text stays hidden.
function NativeControls.CreateCheckButton(factory, parent)
  local check = Base.createTemplatedFrame(factory, "CheckButton", nil, parent, NativeControls.CHECK_TEMPLATE)
  if not check then
    return nil
  end
  check:SetSize(NativeControls.CHECK_SIZE, NativeControls.CHECK_SIZE)
  hideChild(check, "Text")
  return check
end

-- Red-gold panel button in Blizzard's own text colours. Keeps the option
-- button API: callers relabel through `.label:SetText`, and theme refreshes
-- have nothing to paint.
function NativeControls.CreateButton(factory, parent, text, width, height)
  local button = Base.createTemplatedFrame(factory, "Button", nil, parent, NativeControls.BUTTON_TEMPLATE)
  if not button then
    return nil
  end
  button:SetSize(width, height)
  button:SetText(text)
  button.label = {
    SetText = function(_, value)
      button:SetText(value)
    end,
  }
  button.applyThemeColors = function() end
  button.setWidth = function(nextWidth)
    if type(nextWidth) == "number" and nextWidth > 0 then
      button:SetSize(nextWidth, height)
    end
  end
  return button
end

-- Our label, value and range FontStrings stay; the template's own title and
-- Low/High text are hidden.
function NativeControls.CreateSlider(factory, parent)
  local slider = Base.createTemplatedFrame(factory, "Slider", nil, parent, NativeControls.SLIDER_TEMPLATE)
  if not slider then
    return nil
  end
  hideChild(slider, "Text")
  hideChild(slider, "Low")
  hideChild(slider, "High")
  return slider
end

function NativeControls.SliderThumbSize(slider)
  local thumb = type(slider.GetThumbTexture) == "function" and slider:GetThumbTexture() or nil
  local width = thumb and type(thumb.GetWidth) == "function" and thumb:GetWidth() or nil
  if type(width) == "number" and width > 0 then
    return width
  end
  return NativeControls.SLIDER_THUMB_SIZE
end

ns.UIHelpersNativeControls = NativeControls
return NativeControls
