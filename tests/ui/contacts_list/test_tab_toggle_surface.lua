local FakeUI = require("tests.helpers.fake_ui")
local TabParts = require("tests.helpers.tab_toggle_parts")
local Theme = require("WhisperMessenger.UI.Theme")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

-- Modern Whispers/Groups/Requests tabs hang below the window's bottom-left
-- edge at their natural width (like the Native WoW HUD's), each on its own
-- surface, and never take room from the contact list.

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
  local window = factory.CreateFrame("Frame", nil, nil)
  window:SetSize(600, 500)
  window:SetClampRectInsets(0, 0, 0, 0)
  local pane = factory.CreateFrame("Frame", nil, window)
  pane:SetSize(260, 476)
  local toggle = TabToggle.Create(factory, pane, { initialMode = "whispers", windowFrame = window })
  toggle.setShown(true)
  return toggle, window, pane
end

local function hover(button, entering)
  button.scripts[entering and "OnEnter" or "OnLeave"](button)
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  -- test_modern_hover_brightens_inactive_label_and_shows_faint_fill
  Theme.SetPreset("wow_default")
  local t, window, pane = createToggle(factory)
  hover(TabParts.groups(t).btn, true)
  assert(colorsMatch(TabParts.groups(t).label.textColor, Theme.COLORS.text_primary), "hovered inactive label brightens to primary")
  assert(TabParts.groups(t).hover.shown == true, "hovered inactive tab shows the hover fill")
  assert(TabParts.groups(t).hover.color[1] == 1 and TabParts.groups(t).hover.alpha <= 0.06, "hover fill is faint white")
  hover(TabParts.groups(t).btn, false)
  assert(colorsMatch(TabParts.groups(t).label.textColor, Theme.COLORS.text_secondary), "label returns to secondary on leave")
  assert(TabParts.groups(t).hover.shown ~= true, "hover fill hides on leave")

  -- test_modern_hover_on_active_tab_keeps_accent_without_fill
  hover(TabParts.whispers(t).btn, true)
  assert(colorsMatch(TabParts.whispers(t).label.textColor, Theme.COLORS.accent), "active tab keeps accent label on hover")
  assert(TabParts.whispers(t).hover.shown ~= true, "active tab never shows the hover fill")
  hover(TabParts.whispers(t).btn, false)

  -- test_modern_hover_clears_when_tab_becomes_active
  hover(TabParts.groups(t).btn, true)
  TabParts.groups(t).btn.scripts.OnClick(TabParts.groups(t).btn)
  assert(TabParts.groups(t).hover.shown ~= true, "clicked tab drops its hover fill")
  assert(colorsMatch(TabParts.groups(t).label.textColor, Theme.COLORS.accent), "clicked tab label is accent")
  hover(TabParts.groups(t).btn, false)

  -- test_tabs_hang_below_the_window_but_hide_with_the_pane
  local point, relativeTo, relativePoint = table.unpack(t.frame.points[1])
  assert(point == "TOPLEFT" and relativeTo == window and relativePoint == "BOTTOMLEFT", "tabs hang from the window's bottom-left")
  assert(t.frame:GetParent() == pane, "tabs hide with the contacts pane")

  -- test_each_tab_has_its_own_surface
  local whispers = TabParts.whispers(t)
  assert(colorsMatch(whispers.surface.color, Theme.COLORS.bg_primary), "tab surface uses the window background")
  assert(whispers.tint.color[1] == 1 and whispers.tint.alpha > 0 and whispers.tint.alpha <= 0.06, "faint white lift over it")

  -- test_tabs_sit_side_by_side_at_natural_width
  local groups = TabParts.groups(t)
  assert(whispers.btn:GetWidth() > groups.btn:GetWidth(), "a longer label gets a wider tab")
  assert(groups.btn.points[1][2] == whispers.btn, "tabs chain left to right")

  -- test_shown_tabs_extend_the_screen_clamp
  assert(select(4, window:GetClampRectInsets()) == -TabToggle.HEIGHT, "clamp reaches over the hanging tabs")
  t.setShown(false)
  assert(select(4, window:GetClampRectInsets()) == 0, "hidden tabs restore the window's clamp")

  -- test_azeroth_has_the_same_hover_and_surface_tint
  Theme.SetPreset("wow_native")
  local a = createToggle(factory)
  hover(TabParts.groups(a).btn, true)
  assert(TabParts.groups(a).hover.shown == true, "azeroth: hover fill like every preset")
  hover(TabParts.groups(a).btn, false)
  assert(TabParts.whispers(a).tint.color[1] == 1 and TabParts.whispers(a).tint.alpha > 0, "azeroth: surface tint like every preset")

  Theme.SetPreset(previousPreset)
end
