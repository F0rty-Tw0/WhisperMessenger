local FakeUI = require("tests.helpers.fake_ui")
local TabParts = require("tests.helpers.tab_toggle_parts")
local Theme = require("WhisperMessenger.UI.Theme")
local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")

-- Each modern tab hanging below the window is outlined like the window
-- itself (same colour, hairline) on its left, right and bottom; the open top
-- makes it read as hanging from the window's bottom edge.

local function sameColor(a, b)
  return type(a) == "table" and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function hasPoint(region, point)
  for _, pt in ipairs(region.points or {}) do
    if pt[1] == point then
      return true
    end
  end
  return false
end

local function createToggle()
  local factory = FakeUI.NewFactory()
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  local toggle = TabToggle.Create(factory, pane, { initialMode = "whispers", windowFrame = window })
  toggle.setModes({ "whispers", "groups", "requests" })
  return toggle
end

return function()
  local previousPreset = Theme.GetPreset()
  Theme.SetPreset("wow_default")
  local toggle = createToggle()

  -- test_each_tab_has_left_right_and_bottom_border_in_the_window_colour
  for _, part in ipairs({ TabParts.whispers, TabParts.groups }) do
    local border = part(toggle).border
    assert(#border == 3, "three border pieces, got " .. #border)
    for _, edge in ipairs(border) do
      assert(sameColor(edge.color, Theme.COLORS.window_border), "border uses the window border colour")
      assert(edge.snapToPixelGrid == true, "border is pixel-snapped")
    end
  end

  -- test_no_border_on_the_top_edge
  for _, edge in ipairs(TabParts.whispers(toggle).border) do
    assert(not (hasPoint(edge, "TOPLEFT") and hasPoint(edge, "TOPRIGHT")), "no piece spans the tab's top edge")
  end

  -- test_preset_switch_repaints_the_border (every preset shares one
  -- window_border today, so prove the repaint by dirtying the edges first)
  for _, edge in ipairs(TabParts.whispers(toggle).border) do
    edge:SetColorTexture(0, 0, 0, 1)
  end
  Theme.SetPreset("wow_native")
  toggle.setMode(toggle.getMode())
  for _, edge in ipairs(TabParts.whispers(toggle).border) do
    assert(sameColor(edge.color, Theme.COLORS.window_border), "border follows the new preset")
  end

  -- test_underline_and_badge_kept
  assert(TabParts.whispers(toggle).underline.shown == true, "active tab keeps its accent underline")
  assert(TabParts.whispers(toggle).badge ~= nil, "tab keeps its unread badge")

  Theme.SetPreset(previousPreset)
end
