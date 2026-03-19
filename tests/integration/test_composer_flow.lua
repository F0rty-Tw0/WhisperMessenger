local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local sent = {}
  local conversations = {
    ["me::WOW::arthas-area52"] = {
      displayName = "Arthas-Area52",
      lastPreview = "Need help?",
      lastActivityAt = 20,
      messages = {
        {
          direction = "in",
          kind = "user",
          playerName = "Arthas-Area52",
          text = "Need help?",
        },
      },
    },
    ["me::WOW::jaina-proudmoore"] = {
      displayName = "Jaina-Proudmoore",
      lastPreview = "On my way.",
      lastActivityAt = 10,
      messages = {
        {
          direction = "out",
          kind = "user",
          text = "On my way.",
        },
      },
    },
  }
  local contacts = ContactsList.BuildItems(conversations)
  local factory = FakeUI.NewFactory()

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = contacts,
    onSelectConversation = function(conversationKey, item)
      return {
        selectedContact = item,
        conversation = conversations[conversationKey],
      }
    end,
    onSend = function(payload)
      table.insert(sent, payload)
    end,
  })

  -- No conversation selected: header name should be empty/hidden, empty state shown
  assert(window.conversation.headerEmpty ~= nil, "expected empty state element")
  assert(window.conversation.headerEmpty.shown == true, "expected empty state to be shown when no contact selected")
  assert(window.composer.sendButton.disabled == true)

  window.contacts.rows[1].scripts.OnClick()

  -- After selecting Arthas: header should show name
  assert(window.conversation.header.text == "Arthas-Area52")
  assert(window.conversation.transcript.lines[1] == "Need help?")
  assert(window.conversation.transcript.text.text == "Need help?")
  assert(window.contacts.rows[1].selected == true)
  assert(window.contacts.rows[2].selected == false)
  assert(window.composer.sendButton.disabled == false)
  assert(window.composer.input.scripts.OnEnterPressed ~= nil)

  window.composer.input:SetText("On my way")
  window.composer.input.scripts.OnEnterPressed(window.composer.input)

  assert(sent[1].target == "Arthas-Area52")
  assert(sent[1].text == "On my way")
  assert(window.composer.input.text == "")
  assert(#window.conversation.transcript.lines == 1)

  window.refreshSelection({
    selectedContact = contacts[2],
    conversation = conversations[contacts[2].conversationKey],
  })

  assert(window.conversation.header.text == "Jaina-Proudmoore")
  assert(window.conversation.transcript.lines[1] == "You: On my way.")
  assert(window.conversation.transcript.text.text == "You: On my way.")
  assert(window.contacts.rows[1].selected == false)
  assert(window.contacts.rows[2].selected == true)

  window.composer.input:SetText("Meet at the bank")
  window.composer.sendButton.scripts.OnClick()

  assert(sent[2].target == "Jaina-Proudmoore")
  assert(sent[2].conversationKey == "me::WOW::jaina-proudmoore")
  assert(sent[2].text == "Meet at the bank")
  assert(#window.conversation.transcript.lines == 1)

  window.refreshSelection()
  -- After deselecting: header should be empty again
  assert(window.conversation.header.text == "")
  assert(window.conversation.headerEmpty.shown == true, "expected empty state after deselecting")
  assert(window.composer.sendButton.disabled == true)
end
