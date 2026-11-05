local FakeUI = require("tests.helpers.fake_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local FindUI = require("tests.helpers.find_ui")

local LABEL = "Deselect chat input after sending"

local function build(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = BehaviorSettings.Create(factory, parent, config, {
    onChange = function(key, value)
      changes[key] = value
    end,
  })
  return result, changes
end

return function()
  -- test_toggle_exists_and_defaults_off
  do
    local result = build({})
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)) == false, "the setting is opt-in")
  end

  -- test_toggle_shows_saved_value
  do
    local result = build({ deselectComposerOnSend = true })
    assert(FindUI.isToggleOn(FindUI.toggle(result.frame, LABEL)) == true, "the toggle must show the saved value")
  end

  -- test_toggle_fires_on_change
  do
    local result, changes = build({})
    local toggle = FindUI.toggle(result.frame, LABEL)
    toggle:GetScript("OnClick")(toggle)
    assert(changes.deselectComposerOnSend == true, "clicking the toggle must save the setting")
  end

  -- test_reset_turns_it_off
  do
    local result, changes = build({ deselectComposerOnSend = true })
    local reset = FindUI.byLabel(result.frame, "Reset to Defaults")
    reset:GetScript("OnClick")(reset)
    assert(changes.deselectComposerOnSend == false, "Reset to Defaults must turn it off")
  end
end
