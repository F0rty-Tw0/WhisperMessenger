local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local PanelWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PanelWiring")

local function noop() end

local function build(onNavTargetsChanged)
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "Window", nil)
  frame:Show()
  return PanelWiring.Create({
    factory = factory,
    frame = frame,
    layout = {
      optionsPanel = factory.CreateFrame("Frame", nil, frame),
      contactsPane = factory.CreateFrame("Frame", nil, frame),
      contentPane = factory.CreateFrame("Frame", nil, frame),
    },
    chrome = { setBackVisible = noop, setOptionsActive = noop },
    theme = Theme,
    onClose = noop,
    getContactsRail = function()
      return nil
    end,
    onNavTargetsChanged = onNavTargetsChanged,
  })
end

return function()
  -- test_settings_pane_toggle_reports_nav_targets_changed
  do
    local count = 0
    local visibility = build(function()
      count = count + 1
    end).windowVisibility
    visibility.setOptionsVisible(true)
    assert(count == 1, "opening settings asks for a re-scan")
    visibility.setOptionsVisible(false)
    assert(count == 2, "closing settings asks for a re-scan")
  end

  -- test_panel_close_reports_nav_targets_changed
  do
    local count = 0
    local visibility = build(function()
      count = count + 1
    end).windowVisibility
    visibility.setPanelVisible(nil)
    assert(count == 1, "a panel change asks for a re-scan")
  end

  -- test_visibility_without_the_callback_still_works
  do
    local visibility = build(nil).windowVisibility
    visibility.setOptionsVisible(true)
    visibility.setPanelVisible(nil)
  end
end
