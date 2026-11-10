local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")
local WhispersSettings = require("WhisperMessenger.UI.MessengerWindow.WhispersSettings")

local LABEL = "Show their last channel message"

local function create(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = WhispersSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  return result, changes
end

return function()
  Localization.Configure({ language = "enUS" })

  -- test_toggle_saves_show_channel_context
  do
    local result, changes = create({})
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)) == true, "never-saved channel context shows on")
    FindUI.click(FindUI.toggle(result.frame, LABEL))
    assert(changes.showChannelContext == false, "clicking the row off reports showChannelContext = false")
  end

  -- test_saved_off_starts_off
  do
    local result = create({ showChannelContext = false })
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)) == false, "a saved off value starts off")
  end

  -- test_reset_turns_it_back_on
  do
    local result, changes = create({ showChannelContext = false })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.showChannelContext == true, "reset reports showChannelContext = true")
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)) == true, "the row reads on after reset")
  end
end
