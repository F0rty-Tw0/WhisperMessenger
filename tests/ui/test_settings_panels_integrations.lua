local FakeUI = require("tests.helpers.fake_ui")
local SettingsPanels = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")

local function captureCreate(capture)
  return function(_factory, _parent, config, options)
    capture.config = config
    capture.options = options
    return { frame = {}, refreshLayout = function() end, refreshTheme = function() end }
  end
end

return function()
  -- test_only_the_behavior_page_gets_the_integrations
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local behaviorCapture = {}
  local filtersCapture = {}
  local integrations = { registry = {}, enabled = true }
  local panels = SettingsPanels.Create(factory, {
    parent = parent,
    settingsConfig = {},
    integrations = integrations,
    behaviorCreate = captureCreate(behaviorCapture),
    filtersCreate = captureCreate(filtersCapture),
  })
  panels.getPanel(3)
  panels.getPanel(6)
  assert(behaviorCapture.options.integrations == integrations, "behavior page gets the integrations list data")
  assert(filtersCapture.options.integrations == nil, "only the Behavior page gets integrations")
end
