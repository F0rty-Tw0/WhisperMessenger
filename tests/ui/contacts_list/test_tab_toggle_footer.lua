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

local function hover(button, entering)
  button.scripts[entering and "OnEnter" or "OnLeave"](button)
end

local function hasPoint(region, anchor, relative, relAnchor)
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == anchor and pt[2] == relative and pt[3] == relAnchor then
      return true
    end
  end
  return false
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  -- test_modern_hover_brightens_inactive_label_and_shows_faint_fill
  Theme.SetPreset("wow_default")
  local t = createToggle(factory)
  hover(TabParts.groups(t).btn, true)
  assert(colorsMatch(TabParts.groups(t).label.textColor, Theme.COLORS.text_primary), "modern: hovered inactive label brightens to primary")
  assert(TabParts.groups(t).hover.shown == true, "modern: hovered inactive tab shows the hover fill")
  assert(TabParts.groups(t).hover.color[1] == 1 and TabParts.groups(t).hover.alpha <= 0.06, "modern: hover fill is faint white")
  hover(TabParts.groups(t).btn, false)
  assert(colorsMatch(TabParts.groups(t).label.textColor, Theme.COLORS.text_secondary), "modern: label returns to secondary on leave")
  assert(TabParts.groups(t).hover.shown ~= true, "modern: hover fill hides on leave")

  -- test_modern_hover_on_active_tab_keeps_accent_without_fill
  hover(TabParts.whispers(t).btn, true)
  assert(colorsMatch(TabParts.whispers(t).label.textColor, Theme.COLORS.accent), "modern: active tab keeps accent label on hover")
  assert(TabParts.whispers(t).hover.shown ~= true, "modern: active tab never shows the hover fill")
  hover(TabParts.whispers(t).btn, false)

  -- test_modern_hover_clears_when_tab_becomes_active
  hover(TabParts.groups(t).btn, true)
  TabParts.groups(t).btn.scripts.OnClick(TabParts.groups(t).btn)
  assert(TabParts.groups(t).hover.shown ~= true, "modern: clicked tab drops its hover fill")
  assert(colorsMatch(TabParts.groups(t).label.textColor, Theme.COLORS.accent), "modern: clicked tab label is accent")
  hover(TabParts.groups(t).btn, false)

  -- test_modern_footer_has_own_surface
  assert(TabParts.footerTint(t).shown == true, "modern: footer strip shows its tint layer")
  assert(
    TabParts.footerTint(t).color[1] == 1 and TabParts.footerTint(t).alpha > 0 and TabParts.footerTint(t).alpha <= 0.06,
    "modern: footer tint is faint white over the bar bg"
  )
  assert(colorsMatch(TabParts.divider(t).color, Theme.COLORS.divider), "modern: top hairline divider stays")

  -- test_segments_fill_the_bar_height
  assert(hasPoint(TabParts.whispers(t).btn, "BOTTOMRIGHT", t.frame, "BOTTOM"), "whispers segment ends at the bar's bottom centre")
  assert(hasPoint(TabParts.groups(t).btn, "BOTTOMRIGHT", t.frame, "BOTTOMRIGHT"), "groups segment ends at the bar's bottom right")

  -- test_azeroth_has_the_same_hover_and_footer_tint
  Theme.SetPreset("wow_native")
  local a = createToggle(factory)
  hover(TabParts.groups(a).btn, true)
  assert(TabParts.groups(a).hover.shown == true, "azeroth: hover fill like every preset")
  hover(TabParts.groups(a).btn, false)
  assert(TabParts.footerTint(a).shown == true, "azeroth: footer tint like every preset")

  Theme.SetPreset(previousPreset)
  print("PASS: test_tab_toggle_footer")
end
