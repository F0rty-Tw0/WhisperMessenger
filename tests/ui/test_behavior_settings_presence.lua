local FakeUI = require("tests.helpers.fake_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")
local FindUI = require("tests.helpers.find_ui")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = BehaviorSettings.Create(factory, parent, {}, {
    onChange = function(key, value)
      table.insert(changes, { key = key, value = value })
    end,
  })

  -- test_presence_toggles_exist_and_default_on
  local typing = FindUI.toggle(result.frame, "Share typing status")
  local receipts = FindUI.toggle(result.frame, "Send read receipts")
  assert(typing ~= nil, "share typing toggle exists")
  assert(receipts ~= nil, "read receipts toggle exists")
  assert(FindUI.isToggleOn(typing) == true, "typing defaults on")
  assert(FindUI.isToggleOn(receipts) == true, "receipts default on")

  -- test_toggling_reports_setting_keys
  FindUI.click(typing)
  FindUI.click(receipts)
  assert(changes[1].key == "shareTypingStatus" and changes[1].value == false, "typing key reported")
  assert(changes[2].key == "shareReadReceipts" and changes[2].value == false, "receipts key reported")

  -- test_explicit_false_config_starts_off
  local off = BehaviorSettings.Create(factory, parent, { shareTypingStatus = false }, { onChange = function() end })
  assert(FindUI.isToggleOn(FindUI.toggle(off.frame, "Share typing status")) == false, "explicit false starts off")
end
