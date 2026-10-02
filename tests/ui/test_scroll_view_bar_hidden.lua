local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")

-- A view with barHidden (the collapsed contacts rail) still scrolls with the
-- wheel but never shows its bar or gives the bar any of its width.

local VIEW_WIDTH = 46
local VIEW_HEIGHT = 200
local TALL_CONTENT = 1000

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(VIEW_WIDTH, VIEW_HEIGHT)
  local view = ScrollView.Create(factory, parent, { width = VIEW_WIDTH, height = VIEW_HEIGHT, step = 10 })
  view.barHidden = true

  ScrollView.RefreshMetrics(view, TALL_CONTENT)
  ScrollView.Sync(view)

  -- test_hidden_bar_takes_no_width
  assert(view.scrollFrame:GetWidth() == VIEW_WIDTH, "viewport keeps the full width, got " .. tostring(view.scrollFrame:GetWidth()))

  -- test_hidden_bar_stays_hidden_on_overflow
  assert(view.scrollBar:IsShown() == false, "bar stays hidden while content overflows")

  -- test_hidden_bar_view_still_scrolls
  ScrollView.SetVerticalScroll(view, 50)
  assert(ScrollView.GetOffset(view) == 50, "content still scrolls, got " .. tostring(ScrollView.GetOffset(view)))

  -- test_clearing_the_flag_brings_the_bar_back
  view.barHidden = false
  ScrollView.Sync(view)
  assert(view.scrollBar:IsShown() == true, "bar shows again once allowed")
end
