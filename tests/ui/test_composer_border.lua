local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Composer = require("WhisperMessenger.UI.Composer")
local Shapes = require("WhisperMessenger.UI.Helpers.Shapes")

local function colorsMatch(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  local function round(n)
    return math.floor((n or 0) * 1000 + 0.5)
  end
  return round(a[1]) == round(b[1]) and round(a[2]) == round(b[2]) and round(a[3]) == round(b[3]) and round(a[4] or 1) == round(b[4] or 1)
end

local function build(name)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", name, nil)
  parent:SetSize(600, 44)
  return Composer.Create(factory, parent, nil, function() end)
end

return function()
  local previousPreset = Theme.GetPreset()

  -- test_every_preset_draws_a_single_top_hairline
  for _, key in ipairs(Theme.ListPresets()) do
    Theme.SetPreset(key)
    local composer = build("composer_" .. key)
    local border = composer.border
    assert(border ~= nil and border.top ~= nil, key .. ": composer exposes its pane border")
    assert(colorsMatch(border.top.color, Theme.COLORS.divider), key .. ": top hairline uses the divider color")
    assert(border.top.height == Shapes.pixelSize(composer.frame), key .. ": top hairline is one physical pixel")
    assert(border.top.shown == true, key .. ": top hairline shown")
    for _, side in ipairs({ "left", "right", "bottom" }) do
      assert(border[side].shown ~= true, key .. ": " .. side .. " edge hidden")
    end
  end

  -- test_refresh_theme_repaints_the_hairline
  do
    Theme.SetPreset("wow_default")
    local composer = build("composerRefresh")
    Theme.SetPreset("wow_native")
    composer.refreshTheme()
    assert(colorsMatch(composer.border.top.color, Theme.COLORS.divider), "refresh: repainted to wow_native divider")
    Theme.SetPreset("plumber_warm")
    composer.refreshTheme()
    assert(colorsMatch(composer.border.top.color, Theme.COLORS.divider), "refresh: repainted to plumber_warm divider")
  end

  Theme.SetPreset(previousPreset)
  print("  All composer border tests passed")
end
