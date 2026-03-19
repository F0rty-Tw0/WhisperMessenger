local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local sent = {}
  local factory = FakeUI.NewFactory()

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = {},
    selectedContact = {
      displayName = "Arthas-Area52",
      conversationKey = "me::WOW::arthas-area52",
    },
    conversation = {
      messages = {
        {
          direction = "in",
          kind = "user",
          playerName = "Arthas-Area52",
          text = "Need help?",
        },
      },
    },
    onSend = function(payload)
      table.insert(sent, payload)
    end,
  })

  assert(window.conversation.header.text == "Arthas-Area52")
  assert(window.conversation.transcript.lines[1] == "Arthas-Area52: Need help?")

  window.composer.input:SetText("On my way")
  window.composer.sendButton.scripts.OnClick()

  assert(sent[1].target == "Arthas-Area52")
  assert(sent[1].text == "On my way")
  assert(#window.conversation.transcript.lines == 1)
end
