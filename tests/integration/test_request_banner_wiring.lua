local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Localization = require("WhisperMessenger.Locale.Localization")

-- The request banner's Accept / Delete reach the window's callbacks.
return function()
  Localization.Configure({ language = "enUS" })
  local request = { conversationKey = "me::WOW::stranger", displayName = "Stranger", channel = "WOW", isRequest = true, lastActivityAt = 1 }
  local accepted, deleted
  local window = MessengerWindow.Create(FakeUI.NewFactory(), {
    contacts = { request },
    selectedContact = request,
    conversation = { messages = {} },
    onAcceptRequest = function(contact)
      accepted = contact
    end,
    onDeleteRequest = function(contact)
      deleted = contact
    end,
  })

  FindUI.click(FindUI.byLabel(window.conversation.frame, "Accept"))
  FindUI.click(FindUI.byLabel(window.conversation.frame, "Delete"))
  assert(accepted == request, "Accept reaches onAcceptRequest")
  assert(deleted == request, "Delete reaches onDeleteRequest")
end
