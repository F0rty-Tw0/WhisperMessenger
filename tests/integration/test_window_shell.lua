local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local SlashCommands = require("WhisperMessenger.Core.SlashCommands")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local items = ContactsList.BuildItems({
    ["me::WOW::jaina-proudmoore"] = {
      displayName = "Jaina-Proudmoore",
      lastPreview = "Need assistance?",
      unreadCount = 2,
      lastActivityAt = 20,
      channel = "WOW",
    },
    ["me::WOW::anduin-stormrage"] = {
      displayName = "Anduin-Stormrage",
      lastPreview = "On my way.",
      unreadCount = 0,
      lastActivityAt = 10,
      channel = "WOW",
    },
  })

  assert(items[1].displayName == "Jaina-Proudmoore")
  assert(items[2].displayName == "Anduin-Stormrage")

  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)

  local window = MessengerWindow.Create(factory, {
    title = "WhisperMessenger",
    contacts = items,
  })

  assert(window.frame.parent == _G.UIParent)
  assert(window.frame.point[1] == "CENTER")
  assert(window.frame.width == 900)
  assert(window.frame.height == 560)
  assert(window.frame.resizeBounds[1] == 640)
  assert(window.frame.resizeBounds[2] == 420)
  assert(window.frame.background ~= nil)
  assert(window.contactsPane ~= nil)
  assert(window.contentPane ~= nil)
  assert(window.contactsPane.point[1] == "TOPLEFT")
  assert(window.contactsPane.point[5] < 0)
  assert(window.contentPane.point[1] == "TOPLEFT")
  assert(window.contentPane.point[5] < 0)
  assert(window.contactsDivider ~= nil)
  assert(window.headerDivider ~= nil)
  assert(window.threadPane ~= nil)
  assert(window.composerPane ~= nil)
  assert(window.threadPane.height < window.contentPane.height)
  assert(window.composer.frame.parent == window.composerPane)
  assert(window.conversation.frame.parent == window.threadPane)
  assert(#window.contacts.rows == 2)
  assert(window.title.text == "WhisperMessenger")
  assert(window.title.point[1] == "TOPLEFT")
  assert(window.contacts.rows[1].title.point[1] == "LEFT")
  assert(window.contacts.rows[1].preview.text == "")
  assert(window.contacts.rows[1].channel.text == "")
  assert(window.contacts.rows[1].unread.point[1] == "RIGHT")
  assert(window.conversation.header.point[1] == "TOPLEFT")
  assert(window.conversation.statusBanner.point[1] == "TOPLEFT")
  assert(window.conversation.transcript.point[1] == "TOPLEFT")
  assert(window.conversation.transcript.width ~= nil)
  assert(window.conversation.transcript.height ~= nil)
  assert(window.composer.input.point[1] == "BOTTOMLEFT")
  assert(window.composer.input.width ~= nil)
  assert(window.composer.sendButton.point[1] == "BOTTOMRIGHT")
  assert(window.composer.sendButton.width ~= nil)
  _G.UIParent = savedUIParent

  _G.SlashCmdList = {}
  local toggled = false
  SlashCommands.Register({
    toggle = function()
      toggled = true
    end,
  })

  assert(_G.SLASH_WHISPERMESSENGER1 == "/wmsg")
  assert(_G.SLASH_WHISPERMESSENGER2 == "/whispermessenger")
  _G.SlashCmdList.WHISPERMESSENGER()
  assert(toggled == true)
end
