local FakeUI = require("tests.helpers.fake_ui")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- -----------------------------------------------------------------------
  -- test_auto_focus_toggle_label_says_chat_input
  -- -----------------------------------------------------------------------
  do
    local config = { dimWhenMoving = true, autoFocusComposer = false, autoSelectUnread = true }
    local result = BehaviorSettings.Create(factory, parent, config, { onChange = function() end })

    local label = nil
    local row = result.autoFocusToggle.row
    for _, child in ipairs(row.children) do
      if child.text and string.find(child.text, "focus", 1, true) then
        label = child.text
        break
      end
    end

    assert(label ~= nil, "test_auto_focus_toggle_label: should have a label with 'focus'")
    assert(
      string.find(label, "chat input", 1, true) ~= nil,
      "test_auto_focus_toggle_label: label should say 'chat input', got: " .. tostring(label)
    )
  end
end
