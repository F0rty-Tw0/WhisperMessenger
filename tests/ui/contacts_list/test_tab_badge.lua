local FakeUI = require("tests.helpers.fake_ui")
local TabParts = require("tests.helpers.tab_toggle_parts")
local Theme = require("WhisperMessenger.UI.Theme")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

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

local function createToggle(factory)
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 500)
  return TabToggle.Create(factory, parent, { initialMode = "whispers" })
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  -- Token pair + contrast across presets: tests/ui/test_badge_colors.lua.
  -- test_modern_badge_paints_accent
  Theme.SetPreset("wow_default")
  local t = createToggle(factory)
  t.setUnreadCounts(0, 6)
  local bg = TabParts.badgeBg(TabParts.groups(t).badge)
  assert(colorsMatch(bg.vertexColor, Theme.COLORS.unread_badge), "modern: badge circle uses accent")
  assert(
    colorsMatch(TabParts.badgeLabel(TabParts.groups(t).badge).textColor, Theme.COLORS.unread_badge_text),
    "modern: badge text uses on-accent colour"
  )

  -- test_badge_repaints_on_preset_change
  Theme.SetPreset("plumber_warm")
  t.setUnreadCounts(0, 6)
  assert(colorsMatch(bg.vertexColor, Theme.COLORS.accent), "modern: badge follows the new preset accent")

  -- test_azeroth_badge_uses_the_shared_pair
  Theme.SetPreset("wow_native")
  local a = createToggle(factory)
  a.setUnreadCounts(0, 6)
  assert(
    colorsMatch(TabParts.badgeBg(TabParts.groups(a).badge).vertexColor, Theme.COLORS.unread_badge),
    "azeroth: badge uses the shared accent circle"
  )

  Theme.SetPreset(previousPreset)
  print("PASS: test_tab_badge")
end
