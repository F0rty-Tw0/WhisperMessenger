local FakeUI = require("tests.helpers.fake_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")

local LABEL = "Put whispers from strangers in Requests"

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = BehaviorSettings.Create(factory, parent, {}, {
    onChange = function(key, value)
      changes[#changes + 1] = { key = key, value = value }
    end,
  })

  -- test_requests_toggle_defaults_off
  local toggle = FindUI.toggle(result.frame, LABEL)
  assert(toggle ~= nil, "Requests inbox toggle exists")
  assert(FindUI.isToggleOn(toggle) == false, "off by default")

  -- test_toggle_reports_setting_key
  FindUI.click(toggle)
  local last = changes[#changes]
  assert(last.key == "requestsInbox" and last.value == true, "reports requestsInbox = true")

  -- test_saved_true_starts_on
  local on = BehaviorSettings.Create(factory, parent, { requestsInbox = true }, { onChange = function() end })
  assert(FindUI.isToggleOn(FindUI.toggle(on.frame, LABEL)) == true, "saved setting starts on")
end
