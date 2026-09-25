local FakeUI = require("tests.helpers.fake_ui")
local NotificationSettings = require("WhisperMessenger.UI.MessengerWindow.NotificationSettings")
local FindUI = require("tests.helpers.find_ui")

local LABEL = "Flash taskbar on new whisper"

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_flash_toggle_defaults_on_for_existing_users
  do
    local result = NotificationSettings.Create(factory, parent, {}, { onChange = function() end })
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)) == true, "unset setting shows the toggle on")
  end

  -- test_flash_toggle_reflects_saved_off
  do
    local result = NotificationSettings.Create(factory, parent, { flashTaskbarOnWhisper = false }, { onChange = function() end })
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)) == false, "saved off shows the toggle off")
  end

  -- test_clicking_flash_toggle_saves_the_setting
  do
    local changes = {}
    local result = NotificationSettings.Create(factory, parent, {}, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })
    FindUI.click(FindUI.toggle(result.frame, LABEL))
    assert(changes.flashTaskbarOnWhisper == false, "click turns flash off")
  end

  -- test_reset_turns_flash_back_on
  do
    local changes = {}
    local result = NotificationSettings.Create(factory, parent, { flashTaskbarOnWhisper = false }, {
      onChange = function(key, value)
        changes[key] = value
      end,
    })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.flashTaskbarOnWhisper == true, "reset restores flash on")
  end
end
