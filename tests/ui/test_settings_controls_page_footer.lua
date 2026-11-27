local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")
local PageFooter = require("WhisperMessenger.UI.Shared.SettingsControls.PageFooter")

local function newPage()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", nil, nil)
  local anchor = factory.CreateFrame("Frame", nil, frame)
  return factory, frame, anchor
end

local function pointTo(region, relativeTo)
  for _, point in ipairs(region.points or {}) do
    if point[2] == relativeTo then
      return point
    end
  end
  return nil
end

return function()
  -- test_reset_button_is_labelled_and_calls_back_once
  do
    local factory, frame = newPage()
    local panel = SettingsControls.NewPanelRegistry()
    local clicks = 0
    local button = PageFooter.CreateResetButton(factory, frame, panel, "Reset to Defaults", function()
      clicks = clicks + 1
    end)
    assert(FindUI.byLabel(frame, "Reset to Defaults") == button, "the button carries the given label")
    FindUI.click(button)
    assert(clicks == 1, "a click calls the page's callback once")
  end

  -- test_reset_button_is_restyled_with_the_panel
  do
    local factory, frame = newPage()
    local panel = SettingsControls.NewPanelRegistry()
    local button = PageFooter.CreateResetButton(factory, frame, panel, "Reset to Defaults", function() end)
    local painted = nil
    button.applyThemeColors = function(colors)
      painted = colors
    end
    panel:refreshTheme(Theme)
    assert(painted and painted.bg == Theme.COLORS.option_button_bg, "a theme change repaints the button as an option button")
  end

  -- test_bottom_marker_sits_under_the_anchor
  do
    local factory, frame, anchor = newPage()
    local marker = PageFooter.AddBottomMarker(factory, frame, anchor)
    assert(frame._wmBottomMarker == marker, "the page's scroll marker is set")
    local point = pointTo(marker, anchor)
    assert(point and point[1] == "TOPLEFT" and point[3] == "BOTTOMLEFT", "the marker hangs under the anchor")
  end

  -- test_clamp_panel_width
  do
    local maxWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
    assert(PageFooter.ClampPanelWidth(0) == nil, "zero width lays nothing out")
    assert(PageFooter.ClampPanelWidth(-5) == nil, "negative width lays nothing out")
    assert(PageFooter.ClampPanelWidth("wide") == nil, "a non-number lays nothing out")
    assert(PageFooter.ClampPanelWidth(100) == 160, "narrow widths stop at 160")
    assert(PageFooter.ClampPanelWidth(10000) == maxWidth, "wide widths stop at the control width")
    assert(PageFooter.ClampPanelWidth(200.7) == 200, "widths are floored")
  end
end
