local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local conversations = {
    ["me::WOW::arthas"] = { displayName = "Arthas", lastActivityAt = 1, messages = {} },
  }
  local settingsConfig = { quickReplies = { "brb" } }
  local window = MessengerWindow.Create(FakeUI.NewFactory(), {
    contacts = ContactsList.BuildItems(conversations),
    settingsConfig = settingsConfig,
    onSelectConversation = function(conversationKey, item)
      return { selectedContact = item, conversation = conversations[conversationKey] }
    end,
  })
  window.contacts.rows[1].scripts.OnClick()

  -- test_window_composer_lists_saved_quick_replies
  local button, picker = window.composer.quickReplyButton, window.composer.quickReplyPicker
  button.scripts.OnClick(button)
  assert(picker.rows[1].label:GetText() == "brb", "window composer lists the saved quick replies")

  -- test_settings_edit_shows_on_next_open
  picker:close()
  settingsConfig.quickReplies = { "gg" }
  button.scripts.OnClick(button)
  assert(picker.rows[1].label:GetText() == "gg", "edited replies show on the next open")
end
