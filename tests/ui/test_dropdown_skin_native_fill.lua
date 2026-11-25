-- The open list's tooltip panel under the Native look has a solid fill under
-- its art, so the settings rows behind it don't show through even where the
-- tooltip art itself is see-through. It keeps the template's RGB.
local FakeUI = require("tests.helpers.fake_ui")
local Flavor = require("tests.helpers.flavor")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local DropdownSkin = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSkin")

local TOOLTIP_TEMPLATE = "TooltipBackdropTemplate"
-- GameTooltip's default fill RGB (PickerPopup's no-template fallback).
local TOOLTIP_DEFAULT = { 0.09, 0.09, 0.19 }

local function sameColor(actual, expected)
  if type(actual) ~= "table" then
    return false
  end
  for i = 1, #expected do
    if math.abs(actual[i] - expected[i]) > 1e-6 then
      return false
    end
  end
  return true
end

-- Factory whose tooltip frames go through `decorate(frame)` (the template's
-- own methods, as a live client would add them).
local function newFactory(decorate)
  local factory = FakeUI.NewFactory()
  local create = factory.CreateFrame
  factory.CreateFrame = function(frameType, name, parent, template)
    local frame = create(frameType, name, parent, template)
    if template == TOOLTIP_TEMPLATE and decorate then
      decorate(frame)
    end
    return frame
  end
  return factory
end

-- The native panel of a fresh dropdown menu, built on Forever with the
-- gamepad UI on under the Native look.
local function nativePanel(factory)
  local panel
  Flavor.WithPadUI(true, function()
    Flavor.With(true, true, function()
      Hud.Configure("classic")
      local ok, err = pcall(function()
        local row = factory.CreateFrame("Frame", nil, nil)
        local button = factory.CreateFrame("Button", nil, row)
        local _, _, menuSkin = DropdownSkin.CreateMenu(factory, row, button, 200, 24)
        panel = menuSkin.panel
      end)
      Hud.Configure("off")
      if not ok then
        error(err, 0)
      end
    end)
  end)
  assert(panel, "native menu has a panel")
  return panel
end

-- x/y offsets of the fill's anchor `point`.
local function anchorOffset(texture, point)
  for _, pt in ipairs(texture.points or {}) do
    if pt[1] == point then
      return pt[4], pt[5]
    end
  end
  return nil
end

return function()
  -- test_native_panel_fill_is_opaque_in_the_tooltip_default_colour
  do
    local fill = nativePanel(newFactory())._wmFill
    local expected = { TOOLTIP_DEFAULT[1], TOOLTIP_DEFAULT[2], TOOLTIP_DEFAULT[3], 1 }
    assert(fill and sameColor(fill.color, expected), "opaque tooltip default fill when the colour can't be read")
  end

  -- test_native_panel_fill_keeps_the_template_backdrop_rgb
  do
    local fill = nativePanel(newFactory(function(frame)
      function frame:GetBackdropColor()
        return 0.2, 0.3, 0.4, 0.8
      end
    end))._wmFill
    assert(sameColor(fill.color, { 0.2, 0.3, 0.4, 1 }), "template RGB kept at alpha 1")
  end

  -- test_native_panel_fill_reads_the_nine_slice_centre_rgb
  do
    local fill = nativePanel(newFactory(function(frame)
      frame.GetBackdropColor = nil
      frame.NineSlice = {
        GetCenterColor = function()
          return 0.5, 0.6, 0.7, 0.75
        end,
      }
    end))._wmFill
    assert(sameColor(fill.color, { 0.5, 0.6, 0.7, 1 }), "NineSlice centre RGB kept at alpha 1")
  end

  -- test_native_panel_fill_sits_under_the_panel_art
  do
    local fill = nativePanel(newFactory())._wmFill
    assert(fill.drawLayer == "BACKGROUND", "fill draws in the background layer, got " .. tostring(fill.drawLayer))
    assert(fill.drawSublevel == -8, "fill draws at the lowest sublevel, got " .. tostring(fill.drawSublevel))
  end

  -- test_native_panel_fill_stays_inside_the_border
  do
    local fill = nativePanel(newFactory())._wmFill
    local inset = Theme.LAYOUT.NATIVE_BORDER_INSET
    local x, y = anchorOffset(fill, "TOPLEFT")
    local rx, ry = anchorOffset(fill, "BOTTOMRIGHT")
    assert(x == inset and y == -inset and rx == -inset and ry == inset, "fill inset by the border on every side")
  end

  -- test_modern_menu_has_no_panel
  do
    local factory = FakeUI.NewFactory()
    local row = factory.CreateFrame("Frame", nil, nil)
    local button = factory.CreateFrame("Button", nil, row)
    local _, _, menuSkin = DropdownSkin.CreateMenu(factory, row, button, 200, 24)
    assert(menuSkin.panel == nil, "modern menu has no tooltip panel")
  end
end
