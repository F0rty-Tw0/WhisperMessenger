local TabToggle = require("WhisperMessenger.UI.ContactsList.TabToggle")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  -- test_tabs_hide_in_the_phone_chat_view
  do
    local factory = FakeUI.NewFactory()
    local window = factory.CreateFrame("Frame", "Win", nil)
    local toggle = TabToggle.Create(factory, window, {})
    toggle.setModes({ "whispers", "groups" })
    assert(toggle.frame:IsShown(), "tabs show on the list")
    toggle.setChatView(true)
    assert(not toggle.frame:IsShown(), "a chat fills the phone window")
    toggle.setChatView(false)
    assert(toggle.frame:IsShown(), "tabs return with the list")
  end
end
