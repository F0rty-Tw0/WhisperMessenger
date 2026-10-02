local FakeUI = require("tests.helpers.fake_ui")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local ScrollView = require("WhisperMessenger.UI.ScrollView")

-- A window resize relays the options page out; its scrollbar must stay
-- inside the narrower page instead of sliding past its right edge.

local BUILD_WIDTH = 920
local BUILD_HEIGHT = 580
local TALL_OPTIONS = 2000

local function overflowingOptions()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local chrome = ChromeBuilder.Build(factory, parent, { width = BUILD_WIDTH, height = BUILD_HEIGHT }, { useNativeChrome = false })
  local layout = LayoutBuilder.Build(factory, chrome.frame, { width = BUILD_WIDTH, height = BUILD_HEIGHT }, {})
  local osv = layout.optionsScrollView
  ScrollView.RefreshMetrics(osv, TALL_OPTIONS)
  assert(osv.hasOverflow == true, "setup: tall options overflow the page")
  return layout
end

return function()
  -- test_relayout_keeps_the_options_scrollbar_inside_the_page
  do
    local layout = overflowingOptions()
    LayoutBuilder.Relayout(layout, 800, 500)
    local osv = layout.optionsScrollView
    local pageWidth = layout.optionsContentPane.width
    local barRight = osv.scrollFrame:GetWidth() + osv.scrollBar:GetWidth()
    assert(barRight == pageWidth, "bar ends at the page edge " .. tostring(pageWidth) .. ", got " .. tostring(barRight))
  end
end
