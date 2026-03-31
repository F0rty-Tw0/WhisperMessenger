local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local SlashCommands = require("WhisperMessenger.Core.SlashCommands")
local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")

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
  assert(window.frame.width == 920)
  assert(window.frame.height == 580)
  assert(window.frame.resizeBounds[1] == 640)
  assert(window.frame.resizeBounds[2] == 420)
  assert(window.frame.background ~= nil)
  assert(window.contactsPane ~= nil)
  assert(window.contentPane ~= nil)
  assert(window.contactsPane.point[1] == "TOPLEFT")
  assert(window.contactsPane.point[5] < 0)
  assert(window.contentPane.point[1] == "TOPLEFT")
  assert(window.contentPane.point[2] == window.contactsPane, "expected content pane to align with contacts pane")
  assert(window.contentPane.point[5] == 0, "expected content pane vertical offset to match contacts pane")
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
  assert(window.contacts.rows[1].title.point[1] == "TOPLEFT")
  assert(window.contacts.scrollBar ~= nil)
  assert(window.contacts.scrollBar.template == nil, "expected contacts scrollbar to avoid Blizzard scrollbar templates")
  assert(window.contacts.scrollBar.shown == false, "expected contacts scrollbar to stay hidden without overflow")
  assert(
    window.contacts.scrollFrame.width == window.contactsPane.width,
    "expected contacts viewport to use full width when scrollbar is hidden"
  )
  assert(window.conversation.header ~= nil)
  assert(window.conversation.transcript ~= nil)
  assert(window.conversation.transcript.width ~= nil)
  assert(window.conversation.transcript.height ~= nil)
  assert(window.conversation.transcript.scrollBar ~= nil)
  assert(
    window.conversation.transcript.scrollBar.template == nil,
    "expected transcript scrollbar to avoid Blizzard scrollbar templates"
  )
  assert(
    window.conversation.transcript.scrollBar.shown == false,
    "expected transcript scrollbar to stay hidden without overflow"
  )
  assert(
    window.conversation.transcript.scrollFrame.width == window.conversation.transcript.width,
    "expected transcript viewport to use full width when scrollbar is hidden"
  )
  assert(window.composer.input.point[1] == "BOTTOMLEFT")
  assert(window.composer.input.width ~= nil)
  assert(window.composer.sendButton.point[1] == "BOTTOMRIGHT")
  assert(window.composer.sendButton.width ~= nil)
  assert(window.composer.inputBg.color ~= nil, "expected composer input background color")
  assert(
    window.composer.inputBg.color[1] == Theme.COLORS.bg_input[1],
    "composer input red channel should match bg_input"
  )
  assert(
    window.composer.inputBg.color[2] == Theme.COLORS.bg_input[2],
    "composer input green channel should match bg_input"
  )
  assert(
    window.composer.inputBg.color[3] == Theme.COLORS.bg_input[3],
    "composer input blue channel should match bg_input"
  )
  assert(window.composer.inputBg.color[4] == Theme.COLORS.bg_input[4], "composer input alpha should match bg_input")
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
