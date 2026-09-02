local FakeUI = require("tests.helpers.fake_ui")
local SettingsRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsRuntime")

return function()
  local factory = FakeUI.NewFactory()
  local onPanelCreated = nil
  local appearancePanel = { tag = "appearancePanel" }
  local appearanceSettings = { tag = "appearanceSettings" }
  local fakePanels = {
    settingsPanels = { false, false, false, false, false },
    refreshTheme = function() end,
  }

  fakePanels.getPanel = function(index)
    if index == 2 then
      if onPanelCreated then
        onPanelCreated(index, appearancePanel, appearanceSettings)
      end
      return appearancePanel
    end
  end
  fakePanels.getSettings = function(index)
    if index == 2 then
      return appearanceSettings
    end
  end

  local runtime = SettingsRuntime.Create(factory, {
    settingsPanelsCreate = function(_, options)
      onPanelCreated = options.onPanelCreated
      return fakePanels
    end,
  })

  assert(type(runtime.getPanel) == "function", "expected lazy panel getter")
  assert(runtime.getPanel(2) == appearancePanel, "expected appearance panel construction")
  assert(runtime.appearancePanel == appearancePanel, "expected appearance panel alias to update after construction")
  assert(runtime.appearanceSettings == appearanceSettings, "expected appearance settings alias to update after construction")
end
