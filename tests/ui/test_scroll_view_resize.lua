local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ScrollView = require("WhisperMessenger.UI.ScrollView")

-- Resizing a view whose bar is showing must keep the bar's share of the
-- width; otherwise the bar slides past the new right edge.

local VIEW_WIDTH = 300
local VIEW_HEIGHT = 200
local TALL_CONTENT = 1000
local NEW_WIDTH = 240
local NEW_HEIGHT = 150

local function newView()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(VIEW_WIDTH, VIEW_HEIGHT)
  return ScrollView.Create(factory, parent, { width = VIEW_WIDTH, height = VIEW_HEIGHT, step = 10 })
end

local function overflowingView()
  local view = newView()
  ScrollView.RefreshMetrics(view, TALL_CONTENT)
  assert(view.hasOverflow == true, "setup: tall content overflows")
  return view
end

return function()
  -- test_resize_with_overflow_leaves_room_for_the_scrollbar
  do
    local view = overflowingView()
    ScrollView.Resize(view, NEW_WIDTH, NEW_HEIGHT)
    local expected = NEW_WIDTH - Theme.LAYOUT.SCROLLBAR_WIDTH
    assert(view.scrollFrame:GetWidth() == expected, "viewport leaves the bar's width, got " .. tostring(view.scrollFrame:GetWidth()))
  end

  -- test_resize_with_overflow_keeps_the_scrollbar_inside_the_new_width
  do
    local view = overflowingView()
    ScrollView.Resize(view, NEW_WIDTH, NEW_HEIGHT)
    local barRight = view.scrollFrame:GetWidth() + view.scrollBar:GetWidth()
    assert(barRight <= NEW_WIDTH, "bar ends inside the new width, got " .. tostring(barRight))
  end

  -- test_resize_with_overflow_fits_the_scrollbar_to_the_new_height
  do
    local view = overflowingView()
    ScrollView.Resize(view, NEW_WIDTH, NEW_HEIGHT)
    assert(view.scrollBar:GetHeight() == NEW_HEIGHT, "bar spans the new height, got " .. tostring(view.scrollBar:GetHeight()))
  end

  -- test_resize_without_overflow_uses_the_full_width
  do
    local view = newView()
    ScrollView.Resize(view, NEW_WIDTH, NEW_HEIGHT)
    assert(view.scrollFrame:GetWidth() == NEW_WIDTH, "no bar, viewport takes the full width, got " .. tostring(view.scrollFrame:GetWidth()))
  end
end
