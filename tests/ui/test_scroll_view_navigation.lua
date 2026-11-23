local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")

-- A scroll tells the position listener (the transcript's edge fade) once,
-- after the new offset is applied; a range change alone still tells it.

local VIEW_WIDTH = 300
local VIEW_HEIGHT = 200
local TALL_CONTENT = 1000

local function overflowingView()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(VIEW_WIDTH, VIEW_HEIGHT)
  local view = ScrollView.Create(factory, parent, { width = VIEW_WIDTH, height = VIEW_HEIGHT, step = 10 })
  ScrollView.RefreshMetrics(view, TALL_CONTENT)
  assert(view.hasOverflow == true, "setup: tall content overflows")
  return view
end

local function countNotifies(view)
  local seen = { offsets = {} }
  view.onPositionChanged = function(changed)
    seen.offsets[#seen.offsets + 1] = ScrollView.GetOffset(changed)
  end
  return seen
end

return function()
  -- test_set_vertical_scroll_notifies_position_once
  do
    local view = overflowingView()
    local seen = countNotifies(view)
    ScrollView.SetVerticalScroll(view, 10)
    assert(#seen.offsets == 1, "one scroll notifies once, got " .. #seen.offsets)
    assert(seen.offsets[1] == 10, "the notify sees the new offset, got " .. tostring(seen.offsets[1]))
  end

  -- test_sync_alone_still_notifies_position
  do
    local view = overflowingView()
    local seen = countNotifies(view)
    ScrollView.Sync(view)
    assert(#seen.offsets == 1, "a range sync notifies once, got " .. #seen.offsets)
  end
end
