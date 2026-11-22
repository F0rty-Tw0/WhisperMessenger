local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local ScreenEdgeSetting = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ScreenEdgeSetting")
local ScreenEdgeSurface = require("WhisperMessenger.UI.ToggleIcon.ScreenEdgeSurface")
local AnimatedFactory = require("tests.helpers.animated_factory")
local Theme = require("WhisperMessenger.UI.Theme")

local function build()
  local case = { settings = {}, seen = {} }
  case.onChange = SettingsHandler.Create({
    runtime = { store = { config = {} } },
    accountSettings = case.settings,
    onScreenEdgeSetting = function(key, value)
      case.seen[#case.seen + 1] = { key = key, value = value }
    end,
  })
  return case
end

return function()
  -- test_screen_edge_is_saved_and_reported
  do
    local case = build()
    case.onChange("screenEdge", "left")
    assert(case.settings.screenEdge == "left", "saved")
    assert(#case.seen == 1 and case.seen[1].key == "screenEdge" and case.seen[1].value == "left", "reported")
  end

  -- test_glow_is_saved_and_reported
  for _, key in ipairs({ "edgeGlow" }) do
    local case = build()
    case.onChange(key, false)
    assert(case.settings[key] == false, key .. " saved")
    assert(#case.seen == 1 and case.seen[1].key == key and case.seen[1].value == false, key .. " reported")
  end

  -- test_glow_colour_keys_go_through_the_real_handler_to_a_lit_glow
  do
    local settings = {}
    local factory = AnimatedFactory.newAnimatedFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    parent:SetSize(1920, 1080)
    local surface = ScreenEdgeSurface.Create(factory, parent, {
      theme = Theme,
      settings = settings,
      getSide = function()
        return "left"
      end,
      isWindowShown = function()
        return false
      end,
    })
    local onChange = SettingsHandler.Create({
      runtime = { store = { config = {} } },
      accountSettings = settings,
      onScreenEdgeSetting = function(key, value)
        ScreenEdgeSetting.Apply({ runtime = {}, ensureSurface = function() end, updateIconSurfaces = surface.refresh }, key, value)
      end,
    })
    local function vc()
      return surface.glow.pulse.glowTexture.vertexColor
    end
    onChange("edgeGlowCustom", { 0.25, 0.5, 0.75 })
    onChange("edgeGlowColor", "custom")
    assert(settings.edgeGlowCustom[2] == 0.5 and settings.edgeGlowColor == "custom", "table and key stored")
    assert(vc()[1] == 0.25 and vc()[3] == 0.75, "the glow recolours at once")
    onChange("edgeGlowColor", nil)
    onChange("edgeGlowCustom", nil)
    assert(settings.edgeGlowColor == nil and settings.edgeGlowCustom == nil, "reset clears both keys")
    assert(vc()[1] == Theme.COLORS.accent[1] and vc()[3] == Theme.COLORS.accent[3], "back to the theme accent")
  end
end
