local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local DropdownSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")
local DropdownSkin = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSkin")
local FindUI = require("tests.helpers.find_ui")

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  for i = 1, 4 do
    if math.abs((actual[i] or 1) - (expected[i] or 1)) > 0.0001 then
      return false
    end
  end
  return true
end

local function newDropdown(factory)
  local parent = factory.CreateFrame("Frame", nil, nil)
  return DropdownSelector.Create(factory, parent, {
    labelText = "Font Family",
    optionsList = { { key = "default", label = "Default" }, { key = "b", label = "Other" } },
    fallbackKey = "default",
    initial = "default",
    rowWidth = 300,
  })
end

-- First closed-button texture painted with `color` (a rounded-surface fill).
local function fillColored(dd, color)
  local fill = FindUI.find(dd.button, function(node)
    return node.frameType == "Texture" and colorsMatch(node.color, color)
  end)
  return assert(fill, "no closed-button fill painted with the expected colour")
end

local function chevron(dd)
  local glyph = FindUI.find(dd.button, function(node)
    return node.texturePath == DropdownSkin.CHEVRON_TEXTURE
  end)
  return assert(glyph, "closed button has no chevron glyph")
end

local function rightInset(label)
  for _, pt in ipairs(label.points or {}) do
    if pt[1] == "RIGHT" then
      return pt[4]
    end
  end
  return nil
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  Theme.SetPreset("wow_default")

  -- test_modern_dropdown_uses_input_surface
  do
    local dd = newDropdown(factory)
    local surfaceFill = fillColored(dd, Theme.COLORS.bg_input)
    assert(surfaceFill.shown == true, "rounded input surface shown")
  end

  -- test_modern_dropdown_has_down_chevron
  do
    local dd = newDropdown(factory)
    local glyph = chevron(dd)
    assert(glyph.shown == true, "chevron shown")
    assert(glyph.texturePath == DropdownSkin.CHEVRON_TEXTURE, "chevron reuses the back glyph")
    local tc = glyph.texCoords
    assert(tc and #tc == 8 and tc[1] == 1 and tc[2] == 0 and tc[3] == 0 and tc[4] == 0, "back glyph rotated to point down")
    assert(glyph.point[1] == "RIGHT", "chevron sits on the right")
    assert(colorsMatch(glyph.vertexColor, Theme.COLORS.text_secondary), "chevron rests secondary")
    local inset = rightInset(dd.button.label)
    assert(inset and inset <= -(DropdownSkin.CHEVRON_SIZE + 8), "label leaves room for the chevron")
  end

  -- test_modern_dropdown_hover_state
  do
    assert(not colorsMatch(Theme.COLORS.bg_input, Theme.COLORS.bg_contact_hover), "hover wash must differ from the surface")
    local dd = newDropdown(factory)
    local hoverFill = fillColored(dd, Theme.COLORS.bg_contact_hover)
    dd.button.scripts.OnEnter(dd.button)
    assert(hoverFill.shown == true, "hover wash shown")
    assert(colorsMatch(chevron(dd).vertexColor, Theme.COLORS.text_primary), "chevron brightens on hover")
    dd.button.scripts.OnLeave(dd.button)
    assert(hoverFill.shown ~= true, "hover wash hidden on leave")
    assert(colorsMatch(chevron(dd).vertexColor, Theme.COLORS.text_secondary), "chevron restores on leave")
  end

  Theme.SetPreset(previousPreset)
  print("  All modern dropdown tests passed")
end
