-- Hovering the widget or the minimap button lights the logo up in the
-- theme's color (an added-on copy of the logo, tinted with the accent), and
-- brings an idle-gray icon's colors back while the mouse is on it.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local ToggleIcon = require("WhisperMessenger.UI.ToggleIcon")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local IconHover = require("WhisperMessenger.UI.Shared.IconHover")

local function near(a, b)
  return type(a) == "number" and math.abs(a - b) < 1e-6
end

local function idleGray()
  return true
end

-- The minimap button wires its mouse handlers only with a minimap to sit on.
local function minimapButton(options)
  local factory = FakeUI.NewFactory()
  local map = factory.CreateFrame("Frame", "Minimap", nil)
  map:SetSize(140, 140)
  options = options or {}
  options.parent = map
  return MinimapIcon.Create(factory, options)
end

local function hover(button, on)
  button.frame:GetScript(on and "OnEnter" or "OnLeave")(button.frame)
end

local function checkButton(name, button, logo)
  local glow = button.logoGlow
  assert(glow.shown ~= true, name .. ": no glow at rest")
  hover(button, true)
  assert(glow.shown == true, name .. ": glow on hover")
  assert(glow.texturePath == logo.texturePath, name .. ": glow is a copy of the logo")
  assert(glow.blendMode == "ADD", name .. ": added on, so it lights the logo up")
  local accent = Theme.COLORS.accent
  local c = glow.vertexColor
  assert(near(c[1], accent[1]) and near(c[2], accent[2]) and near(c[3], accent[3]), name .. ": in the theme's accent")
  assert(near(c[4], IconHover.STRENGTH), name .. ": at the hover strength")
  assert(logo.alpha == nil or near(logo.alpha, 1), name .. ": the logo itself doesn't fade")
  hover(button, false)
  assert(glow.shown == false, name .. ": glow gone after hover")
end

return function()
  local previousPreset = Theme.GetPreset()
  Hud.Configure("off")

  for _, preset in ipairs({ "wow_default", "wow_native", "jade_dark" }) do
    Theme.SetPreset(preset)

    -- test_widget_hover_glows_in_the_theme_color
    do
      local icon = ToggleIcon.Create(FakeUI.NewFactory(), {})
      checkButton(preset .. " widget", icon, icon.label)
    end

    -- test_minimap_hover_glows_in_the_theme_color
    do
      local minimap = minimapButton()
      checkButton(preset .. " minimap", minimap, minimap.iconTex)
    end
  end
  Theme.SetPreset("wow_default")

  -- test_hover_brings_an_idle_gray_icon_back_to_color
  do
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), { getIconDesaturated = idleGray })
    icon.setUnreadCount(0)
    assert(icon.label.desaturated == true, "gray when idle")
    hover(icon, true)
    assert(icon.label.desaturated == false, "colors back on hover")
    assert(icon.logoGlow.shown == true, "and the glow")
    hover(icon, false)
    assert(icon.label.desaturated == true, "gray again after hover")
  end
  do
    local minimap = minimapButton({ getIconDesaturated = idleGray })
    minimap.setUnreadCount(0)
    hover(minimap, true)
    assert(minimap.iconTex.desaturated == false and minimap.logoGlow.shown == true, "minimap: colors back and glow")
    hover(minimap, false)
    assert(minimap.iconTex.desaturated == true, "minimap: gray again")
  end

  -- test_ring_hud_glow_follows_the_rimless_logo
  Hud.Configure("classic")
  do
    local icon = ToggleIcon.Create(FakeUI.NewFactory(), {})
    hover(icon, true)
    assert(icon.logoGlow.texturePath == icon.label.texturePath, "glow uses whichever logo is showing")
    assert(icon.logoGlow.allPoints == icon.label, "and sits on it")
    hover(icon, false)
  end
  Hud.Configure("off")

  if previousPreset then
    Theme.SetPreset(previousPreset)
  end
end
