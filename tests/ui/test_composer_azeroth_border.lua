local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Composer = require("WhisperMessenger.UI.Composer")

local function colorsMatch(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return false
  end
  local function round(n)
    return math.floor((n or 0) * 1000 + 0.5)
  end
  return round(a[1]) == round(b[1])
    and round(a[2]) == round(b[2])
    and round(a[3]) == round(b[3])
    and round(a[4] or 1) == round(b[4] or 1)
end

return function()
  local previousPreset = Theme.GetPreset()

  -- ---------------------------------------------------------------------
  -- Composer draws a faint 1px border on its own pane using the theme's
  -- subtle `divider` color — the same color the contacts and search
  -- dividers use — so it reads as a barely-visible chrome line instead of
  -- a highlighted frame, consistent across all presets including Azeroth.
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_native")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parentAzerothComposer", nil)
    parent:SetSize(600, 52)

    local composer = Composer.Create(factory, parent, nil, function() end)
    assert(composer.border ~= nil, "azeroth_composer: Composer should expose a themed border on its own pane")
    assert(composer.border.top ~= nil, "azeroth_composer: border.top should exist")
    assert(composer.border.bottom ~= nil, "azeroth_composer: border.bottom should exist")
    assert(composer.border.left ~= nil, "azeroth_composer: border.left should exist")
    assert(composer.border.right ~= nil, "azeroth_composer: border.right should exist")
    assert(
      colorsMatch(composer.border.top.color, Theme.COLORS.divider),
      "azeroth_composer: border color should match the subtle divider color under wow_native"
    )
    assert(
      composer.border.top.height == Theme.DIVIDER_THICKNESS,
      "azeroth_composer: border thickness should be 1px (DIVIDER_THICKNESS), got "
        .. tostring(composer.border.top.height)
    )
    assert(
      composer.border.left.width == Theme.DIVIDER_THICKNESS,
      "azeroth_composer: vertical border thickness should be 1px, got " .. tostring(composer.border.left.width)
    )
  end

  -- ---------------------------------------------------------------------
  -- Modern presets share the same mechanism and divider color.
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parentModernComposer", nil)
    parent:SetSize(600, 52)

    local composer = Composer.Create(factory, parent, nil, function() end)
    assert(
      colorsMatch(composer.border.top.color, Theme.COLORS.divider),
      "modern_composer: border color should match divider under wow_default"
    )
  end

  -- ---------------------------------------------------------------------
  -- refreshTheme repaints to the new theme's divider color on preset
  -- switch so the faint chrome line stays consistent with the rest of the
  -- window.
  -- ---------------------------------------------------------------------
  do
    Theme.SetPreset("wow_default")
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parentRefreshComposer", nil)
    parent:SetSize(600, 52)

    local composer = Composer.Create(factory, parent, nil, function() end)
    assert(
      colorsMatch(composer.border.top.color, Theme.COLORS.divider),
      "refresh: precondition — wow_default divider"
    )

    Theme.SetPreset("wow_native")
    composer.refreshTheme()
    assert(
      colorsMatch(composer.border.top.color, Theme.COLORS.divider),
      "refresh: should repaint border to wow_native divider after preset switch"
    )

    Theme.SetPreset("plumber_warm")
    composer.refreshTheme()
    assert(
      colorsMatch(composer.border.top.color, Theme.COLORS.divider),
      "refresh: should repaint border to plumber_warm divider after preset switch"
    )
  end

  if previousPreset then
    Theme.SetPreset(previousPreset)
  end

  print("  All composer themed border tests passed")
end
