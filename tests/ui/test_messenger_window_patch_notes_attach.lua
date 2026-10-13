-- Attach wires the window's "?" button to open Options on What's New.
local FakeUI = require("tests.helpers.fake_ui")
local PatchNotesRuntime = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PatchNotesRuntime")
local SettingsPanels = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")

return function()
  -- test_button_click_opens_options_on_the_whats_new_page
  do
    local factory = FakeUI.NewFactory()
    local button = factory.CreateFrame("Button", nil, nil)
    local calls = { visible = nil, tab = nil }
    local settingsConfig = {}
    PatchNotesRuntime.Attach({
      chrome = { patchNotesButton = button, setPatchNotesGlow = function() end },
      layout = {},
      settingsConfig = settingsConfig,
      setOptionsVisible = function(visible)
        calls.visible = visible
      end,
      scriptResult = {
        selectSettingsTab = function(index)
          calls.tab = index
        end,
      },
    })
    button:GetScript("OnClick")(button)
    assert(calls.visible == true, "options panel opened")
    assert(calls.tab == SettingsPanels.PATCH_NOTES_INDEX, "What's New page selected")
    assert(settingsConfig.patchNotesSeenVersion ~= nil, "seen version recorded")
  end

  -- test_chrome_without_a_button_is_left_alone
  do
    local settingsConfig = {}
    PatchNotesRuntime.Attach({ chrome = {}, layout = {}, settingsConfig = settingsConfig, scriptResult = {} })
    assert(next(settingsConfig) == nil, "a chrome without a patch-notes button must wire nothing")
  end
end
