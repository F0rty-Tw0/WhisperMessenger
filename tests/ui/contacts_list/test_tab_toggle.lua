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

  -- test_modern_tabs_are_text_with_accent_underline
  Theme.SetPreset("wow_default")
  local toggle = createToggle(factory)
  assert(colorsMatch(TabParts.whispers(toggle).label.textColor, Theme.COLORS.accent), "modern: active tab label uses accent")
  assert(colorsMatch(TabParts.groups(toggle).label.textColor, Theme.COLORS.text_secondary), "modern: inactive tab label uses secondary text")
  assert(TabParts.whispers(toggle).underline.shown == true, "modern: active tab shows underline")
  assert(TabParts.whispers(toggle).underline.height == 2, "modern: underline is 2px")
  assert(colorsMatch(TabParts.whispers(toggle).underline.color, Theme.COLORS.accent_bar), "modern: underline uses accent")
  assert(TabParts.groups(toggle).underline.shown ~= true, "modern: inactive tab has no underline")

  -- test_modern_underline_follows_mode
  toggle.setMode("groups")
  assert(
    TabParts.groups(toggle).underline.shown == true and TabParts.whispers(toggle).underline.shown == false,
    "modern: underline follows active tab"
  )
  assert(colorsMatch(TabParts.groups(toggle).label.textColor, Theme.COLORS.accent), "modern: new active tab label uses accent")

  -- test_azeroth_uses_the_accent_underline_too
  Theme.SetPreset("wow_native")
  toggle.setMode("whispers")
  assert(
    TabParts.whispers(toggle).underline.shown == true and TabParts.groups(toggle).underline.shown == false,
    "azeroth: underline on the active tab"
  )
  assert(colorsMatch(TabParts.whispers(toggle).label.textColor, Theme.COLORS.accent), "azeroth: active label uses the gold accent")

  -- test_label_and_badge_center_as_one_group
  -- Fake GetStringWidth = 7px per char; badge adds BADGE_GAP 4 + BADGE_SIZE 14.
  local function lastPoint(region, anchor)
    local found
    for _, pt in ipairs(region.points or {}) do
      if pt[1] == anchor then
        found = pt
      end
    end
    return found
  end
  for _, key in ipairs({ "wow_default", "wow_native" }) do
    Theme.SetPreset(key)
    local t = createToggle(factory)
    t.setUnreadCounts(3, 0)
    local whispersCenter = lastPoint(TabParts.whispers(t).label, "CENTER")
    assert(whispersCenter[4] == -9, key .. ": label+badge group centered (label shifted -9), got " .. tostring(whispersCenter[4]))
    assert(lastPoint(TabParts.groups(t).label, "CENTER")[4] == 0, key .. ": label without badge stays centered")
    t.setUnreadCounts(0, 0)
    assert(lastPoint(TabParts.whispers(t).label, "CENTER")[4] == 0, key .. ": re-centers when the badge hides")
  end

  -- test_underline_follows_content_width
  do
    Theme.SetPreset("wow_default")
    local t = createToggle(factory)
    t.setUnreadCounts(3, 0)
    assert(
      TabParts.whispers(t).underline.width == 56 + 18 + 12,
      "modern: underline spans label+badge + 12px, got " .. tostring(TabParts.whispers(t).underline.width)
    )
    local pt = lastPoint(TabParts.whispers(t).underline, "BOTTOM")
    assert(pt ~= nil and pt[4] == 0, "modern: underline centered under the group")
    t.setMode("groups")
    assert(
      TabParts.groups(t).underline.width == 42 + 12,
      "modern: underline follows the groups label width, got " .. tostring(TabParts.groups(t).underline.width)
    )
  end

  Theme.SetPreset(previousPreset)
  print("PASS: test_tab_toggle")
end
