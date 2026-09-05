local FakeUI = require("tests.helpers.fake_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

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
  assert(result.shareTypingToggle ~= nil, "share typing toggle exists")
  assert(result.shareReadReceiptsToggle ~= nil, "read receipts toggle exists")
  assert(result.shareTypingToggle.getValue() == true, "typing defaults on")
  assert(result.shareReadReceiptsToggle.getValue() == true, "receipts default on")

  -- test_toggling_reports_setting_keys
  result.shareTypingToggle.dot.scripts.OnClick(result.shareTypingToggle.dot)
  result.shareReadReceiptsToggle.dot.scripts.OnClick(result.shareReadReceiptsToggle.dot)
  assert(changes[1].key == "shareTypingStatus" and changes[1].value == false, "typing key reported")
  assert(changes[2].key == "shareReadReceipts" and changes[2].value == false, "receipts key reported")

  -- test_explicit_false_config_starts_off
  local off = BehaviorSettings.Create(factory, parent, { shareTypingStatus = false }, { onChange = function() end })
  assert(off.shareTypingToggle.getValue() == false, "explicit false starts off")
end
