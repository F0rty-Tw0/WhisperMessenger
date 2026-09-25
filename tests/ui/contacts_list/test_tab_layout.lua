local FakeUI = require("tests.helpers.fake_ui")
local TabLayout = require("WhisperMessenger.UI.ContactsList.TabLayout")

-- Three footer tabs wrap to two rows when a label (+ badge) no longer fits a
-- third of the strip: Whispers and Groups share the top row, Requests spans
-- the bottom row.

local ROW = 24

local function makeTabs(factory, frame, count)
  local visible = {}
  for i = 1, count do
    visible[i] = { btn = factory.CreateFrame("Button", nil, frame), natural = 86 }
  end
  return visible
end

local function naturalWidth(tab)
  return tab.natural
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_three_tabs_wrap_when_a_label_is_wider_than_a_third
  do
    local visible = makeTabs(factory, nil, 3)
    assert(TabLayout.NeedsWrap(visible, 210, naturalWidth) == true, "86px label does not fit 70px third")
  end

  -- test_three_tabs_stay_on_one_row_when_labels_fit
  do
    local visible = makeTabs(factory, nil, 3)
    assert(TabLayout.NeedsWrap(visible, 300, naturalWidth) == false, "86px label fits 100px third")
  end

  -- test_two_tabs_never_wrap
  do
    local visible = makeTabs(factory, nil, 2)
    assert(TabLayout.NeedsWrap(visible, 150, naturalWidth) == false, "two tabs keep one row")
  end

  -- test_unknown_width_never_wraps
  do
    local visible = makeTabs(factory, nil, 3)
    assert(TabLayout.NeedsWrap(visible, 0, naturalWidth) == false, "a strip not laid out yet keeps one row")
  end

  -- test_wrapped_anchor_puts_first_two_on_top_and_third_below
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    frame:SetSize(210, 2 * ROW)
    local visible = makeTabs(factory, frame, 3)
    TabLayout.Anchor(frame, visible, 1, ROW)
    local first, middle, last = visible[1].btn.points, visible[2].btn.points, visible[3].btn.points
    assert(first[1][1] == "TOPLEFT" and first[1][3] == "TOPLEFT" and first[1][5] == -1, "first starts top-left under the divider")
    assert(first[2][1] == "BOTTOMRIGHT" and first[2][3] == "TOP" and first[2][5] == -ROW, "first ends mid-strip, one row down")
    assert(middle[1][1] == "TOPLEFT" and middle[1][3] == "TOP" and middle[1][5] == -1, "middle starts mid-strip")
    assert(middle[2][1] == "BOTTOMRIGHT" and middle[2][3] == "TOPRIGHT" and middle[2][5] == -ROW, "middle ends top-right, one row down")
    assert(last[1][1] == "TOPLEFT" and last[1][3] == "TOPLEFT" and last[1][5] == -ROW, "last starts at the second row")
    assert(last[2][1] == "BOTTOMRIGHT" and last[2][3] == "BOTTOMRIGHT", "last spans the full bottom row")
  end

  -- test_single_row_anchor_still_splits_in_thirds
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    frame:SetSize(300, ROW)
    local visible = makeTabs(factory, frame, 3)
    TabLayout.Anchor(frame, visible, 1)
    assert(visible[1].btn.points[2][4] == 100, "first tab is a third of 300px")
    assert(visible[3].btn.points[1][4] == -100, "last tab starts a third from the right")
  end
end
