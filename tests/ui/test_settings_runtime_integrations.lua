local FakeUI = require("tests.helpers.fake_ui")
local SettingsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsRuntime")

return function()
  -- test_settings_runtime_forwards_integrations_to_the_panels
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local integrations = { registry = {}, enabled = true }
  local seen
  SettingsRuntime.Create(factory, {
    parent = parent,
    integrations = integrations,
    settingsPanelsCreate = function(_factory, panelOptions)
      seen = panelOptions
      return {
        settingsPanels = {},
        getPanel = function() end,
        getSettings = function() end,
        refreshTheme = function() end,
        refreshLayout = function() end,
      }
    end,
  })
  assert(seen and seen.integrations == integrations, "settingsPanelsCreate receives options.integrations")
end
