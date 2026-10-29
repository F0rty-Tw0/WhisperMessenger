-- The minimap button wears the game's standard minimap-button ring, laid out
-- like LibDBIcon's buttons (what most addons' minimap buttons use): the
-- Modern layout on clients with the addon compartment (retail, Forever),
-- the Classic layout without it. The ring can be turned off, which leaves
-- the plain dark disc with a thin hoop.
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local MinimapIcon = require("WhisperMessenger.UI.MinimapIcon.MinimapIcon")
local Look = require("WhisperMessenger.UI.MinimapIcon.MinimapButtonLook")
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")

local function point(region)
  local p = region.point or {}
  return p[1], p[2], p[3], p[4], p[5]
end

local function create(border, style)
  return MinimapIcon.Create(FakeUI.NewFactory(), {
    getMinimapBorder = border ~= nil and function()
      return border
    end or nil,
    getMinimapBorderStyle = style and function()
      return style
    end or nil,
  })
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")

  -- test_border_on_by_default_classic_layout_without_compartment
  rawset(_G, "AddonCompartmentFrame", nil)
  do
    local m = create()
    assert(m.border.texturePath == Look.BORDER_TEXTURE, "standard ring, got " .. tostring(m.border.texturePath))
    assert(m.border.width == 53, "classic ring is 53, got " .. tostring(m.border.width))
    local p, rel, rp, x, y = point(m.border)
    assert(p == "TOPLEFT" and rel == m.frame and rp == "TOPLEFT" and x == 0 and y == 0, "ring from the top left")
    assert(m.background.texturePath == Look.BACKGROUND_TEXTURE and m.background.width == 20, "classic background")
    p, rel, rp, x, y = point(m.background)
    assert(p == "CENTER" and rp == "TOPLEFT" and x == 17 and y == -15, "classic background sits off-centre like LibDBIcon's")
    p, rel, rp, x, y = point(m.iconTex)
    assert(p == "CENTER" and rp == "TOPLEFT" and x == 15.5 and y == -14.5, "classic icon position")
    assert(m.frame.width == 31, "LibDBIcon button size")
    assert(m.highlight.shown ~= false and m.highlight.texturePath == Look.HIGHLIGHT_TEXTURE, "standard hover highlight")
  end

  -- test_auto_uses_modern_layout_with_compartment
  rawset(_G, "AddonCompartmentFrame", {})
  do
    local m = create()
    assert(m.border.width == 50, "modern ring is 50")
    local p, _, rp, x, y = point(m.background)
    assert(m.background.width == 24 and p == "CENTER" and rp == "TOPLEFT" and x == 15.5 and y == -15.5, "modern background centred")
    p, _, rp, x, y = point(m.iconTex)
    assert(p == "CENTER" and x == 15.5 and y == -15.5, "modern icon centred")
  end

  -- test_style_choice_overrides_the_game
  do
    local m = create(true, "classic")
    assert(m.border.width == 53, "classic chosen on a modern client")
  end
  rawset(_G, "AddonCompartmentFrame", nil)
  do
    local m = create(true, "modern")
    assert(m.border.width == 50, "modern chosen on a classic client")
  end

  -- test_border_off_keeps_the_plain_disc
  do
    local m = create(false)
    assert(m.border.texturePath == Look.PLAIN_BORDER_TEXTURE, "thin hoop")
    assert(m.background.texturePath == Look.PLAIN_BACKGROUND_TEXTURE, "dark disc")
    assert(m.highlight.shown == false, "no ring highlight")
    assert(m.frame.width == 30, "plain size")
  end

  -- test_setting_change_reapplies_on_refresh
  do
    local border = false
    local m = MinimapIcon.Create(FakeUI.NewFactory(), {
      getMinimapBorder = function()
        return border
      end,
    })
    border = true
    m.refreshTheme()
    assert(m.border.texturePath == Look.BORDER_TEXTURE, "ring after turning it on")
    border = false
    m.refreshTheme()
    assert(m.border.texturePath == Look.PLAIN_BORDER_TEXTURE, "hoop after turning it off")
  end

  -- test_ring_and_background_untinted_like_other_buttons
  do
    local m = create(true)
    local b, bg = m.border.vertexColor, m.background.vertexColor
    assert(b[1] == 1 and b[2] == 1 and b[3] == 1, "ring in its own colors")
    assert(bg[1] == 1 and bg[2] == 1 and bg[3] == 1, "background in its own colors")
  end

  -- test_border_settings_repaint_the_minimap_button
  do
    local refreshed = 0
    local accountSettings = {}
    local onChange = SettingsHandler.Create({
      runtime = { store = { config = {} } },
      accountSettings = accountSettings,
      getIcon = function()
        return nil
      end,
      getMinimapIcon = function()
        return {
          refreshTheme = function()
            refreshed = refreshed + 1
          end,
        }
      end,
    })
    onChange("minimapBorder", false)
    onChange("minimapBorderStyle", "modern")
    assert(accountSettings.minimapBorder == false and accountSettings.minimapBorderStyle == "modern", "both saved")
    assert(refreshed == 2, "minimap repainted for each, got " .. refreshed)
  end

  rawset(_G, "AddonCompartmentFrame", nil)
  if previousPreset then
    Theme.SetPreset(previousPreset)
  end
end
