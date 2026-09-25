local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")

-- Window wiring: Reply fills the "Replying to" strip for that conversation
-- only and rides on the next send; Retry puts a failed text back into the
-- composer; the other bubble buttons reach the window callback.
local ARTHAS = "me::WOW::arthas-area52"
local JAINA = "me::WOW::jaina-proudmoore"

local function replyStrip(window)
  local label = FindUI.find(window.frame, function(node)
    return node.frameType == "FontString" and type(node.text) == "string" and string.find(node.text, "Replying to", 1, true) ~= nil
  end)
  return label and label.parent.shown == true and label or nil
end

return function()
  Localization.Configure({ language = "enUS" })
  local incoming = { id = "1", direction = "in", kind = "user", text = "you coming?", sentAt = 10, playerName = "Arthas-Area52", wireId = "w1" }
  local failed = {
    id = "2",
    direction = "out",
    kind = "user",
    text = "oops",
    sentAt = 20,
    delivery = "failed",
    replyTo = { id = "1", wireId = "w1", direction = "in", author = "Arthas-Area52", snippet = "you coming?" },
  }
  local conversations = {
    [ARTHAS] = { displayName = "Arthas-Area52", channel = "WOW", lastActivityAt = 20, messages = { incoming, failed } },
    [JAINA] = { displayName = "Jaina-Proudmoore", channel = "WOW", lastActivityAt = 10, messages = {} },
  }
  local sent, actions = {}, {}
  local contacts = ContactsList.BuildItems(conversations)
  local window = MessengerWindow.Create(FakeUI.NewFactory(), {
    contacts = contacts,
    onSelectConversation = function(conversationKey, item)
      return { selectedContact = item, conversation = conversations[conversationKey] }
    end,
    onSend = function(payload)
      sent[#sent + 1] = payload
      return true
    end,
    onMessageAction = function(contact, message, action)
      actions[#actions + 1] = { contact = contact, message = message, action = action }
      return true
    end,
  })
  window.contacts.rows[1].scripts.OnClick()

  -- test_reply_shows_the_strip_and_rides_on_the_send
  window.conversation.transcript.onReply(incoming)
  local strip = replyStrip(window)
  assert(
    strip and string.find(strip.text, "Arthas-Area52", 1, true) and string.find(strip.text, "you coming?", 1, true),
    "strip names the quoted message"
  )
  assert(#actions == 0, "reply is handled in the window, not the model")

  -- test_reply_does_not_follow_to_another_contact
  window.contacts.rows[2].scripts.OnClick()
  assert(replyStrip(window) == nil, "Jaina's conversation is not replying")
  window.contacts.rows[1].scripts.OnClick()
  assert(replyStrip(window) ~= nil, "back on Arthas: still replying")

  window.composer.input:SetText("on my way")
  window.composer.input.scripts.OnEnterPressed(window.composer.input)
  assert(sent[1].replyTo and sent[1].replyTo.wireId == "w1" and sent[1].replyTo.snippet == "you coming?", "reply attached")
  assert(replyStrip(window) == nil, "strip closes after sending")

  -- test_retry_resends_without_touching_the_composer
  window.conversation.transcript.onMessageAction(failed, "retry")
  assert(actions[1].action == "retry" and actions[1].message == failed, "retry reaches the window callback")
  assert(window.composer.input:GetText() == "", "composer left alone")
  assert(replyStrip(window) == nil, "no reply strip reopened")
end
