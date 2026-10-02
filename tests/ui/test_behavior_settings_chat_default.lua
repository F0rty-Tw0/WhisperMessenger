-- "Hide whispers from default chat" defaults on: Reset to Defaults turns it
-- on. An account that never saved it still shows off (test_behavior_settings).
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

local function create(config)
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
  -- test_reset_hides_whispers_from_default_chat
  do
    local result, changes = create({ hideFromDefaultChat = false })
    FindUI.click(FindUI.byLabel(result.frame, "Reset to Defaults"))
    assert(changes.hideFromDefaultChat == true, "reset turns hide-from-chat on, got " .. tostring(changes.hideFromDefaultChat))
  end
end
