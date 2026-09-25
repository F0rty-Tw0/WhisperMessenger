local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

local ARTHAS = "me::WOW::arthas-area52"
local JAINA = "me::WOW::jaina-proudmoore"

local function type_(window, text)
  window.composer.input:SetText(text)
  window.composer.input.scripts.OnTextChanged(window.composer.input)
end

return function()
  local conversations = {
    [ARTHAS] = { displayName = "Arthas-Area52", lastActivityAt = 20, messages = {} },
    [JAINA] = { displayName = "Jaina-Proudmoore", lastActivityAt = 10, messages = {} },
  }
  local drafts = {}
  local sent = {}
  local contacts = ContactsList.BuildItems(conversations)
  local window = MessengerWindow.Create(FakeUI.NewFactory(), {
    contacts = contacts,
    onSelectConversation = function(conversationKey, item)
      return { selectedContact = item, conversation = conversations[conversationKey] }
    end,
    onSend = function(payload)
      table.insert(sent, payload)
      return true
    end,
    getDraft = function(conversationKey)
      return drafts[conversationKey]
    end,
    onDraftChanged = function(conversationKey, text)
      drafts[conversationKey] = text ~= "" and text or nil
    end,
  })

  -- test_switching_contact_does_not_carry_text_to_the_next_contact
  window.contacts.rows[1].scripts.OnClick()
  type_(window, "secret plan for arthas")
  window.contacts.rows[2].scripts.OnClick()
  assert(window.composer.input:GetText() == "", "half-typed text must not follow to another contact")
  assert(drafts[ARTHAS] == "secret plan for arthas", "text is kept as Arthas's draft")

  -- test_switching_back_restores_the_draft
  type_(window, "note for jaina")
  window.contacts.rows[1].scripts.OnClick()
  assert(window.composer.input:GetText() == "secret plan for arthas", "returning restores that contact's draft")
  window.contacts.rows[2].scripts.OnClick()
  assert(window.composer.input:GetText() == "note for jaina", "each contact keeps its own draft")

  -- test_send_goes_to_the_selected_contact_only_and_clears_its_draft
  window.composer.input.scripts.OnEnterPressed(window.composer.input)
  assert(sent[1].conversationKey == JAINA and sent[1].text == "note for jaina", "message goes to the contact whose draft it is")
  assert(drafts[JAINA] == nil, "sending clears the draft")

  -- test_refresh_of_same_selection_keeps_live_text
  type_(window, "still typing")
  window.refreshSelection({ selectedContact = contacts[2], conversation = conversations[JAINA] })
  assert(window.composer.input:GetText() == "still typing", "a refresh of the same conversation must not reset the input")

  -- test_deselecting_clears_the_input
  window.refreshSelection()
  assert(window.composer.input:GetText() == "", "no selection -> empty input")
  assert(drafts[JAINA] == "still typing", "deselecting keeps the draft")
end
