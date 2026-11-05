-- The saved setting reaches the composer, and is read live: the settings
-- panel writes to this same table without rebuilding the window.

local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

local function makeWindow(settingsConfig)
  return MessengerWindow.Create(FakeUI.NewFactory(), {
    title = "WhisperMessenger",
    contacts = {},
    selectedContact = { conversationKey = "me::WOW::arthas", displayName = "Arthas", channel = "WOW" },
    settingsConfig = settingsConfig,
    onSend = function()
      return true
    end,
  })
end

local function send(window)
  local input = window.composer.input
  input:SetFocus()
  input:SetText("hi")
  input.scripts.OnEnterPressed(input)
end

return function()
  -- test_setting_on_clears_focus_after_send
  do
    local window = makeWindow({ deselectComposerOnSend = true })
    send(window)
    assert(window.composer.input._hasFocus == false, "the setting must reach the composer")
    assert(window.composer.input:GetText() == "", "the send must have gone through")
  end

  -- test_setting_read_live
  do
    local settingsConfig = { deselectComposerOnSend = true }
    local window = makeWindow(settingsConfig)
    settingsConfig.deselectComposerOnSend = false
    send(window)
    assert(window.composer.input._hasFocus == true, "turning the setting off must apply without a rebuild")
    assert(window.composer.input:GetText() == "", "the send must have gone through")
  end
end
