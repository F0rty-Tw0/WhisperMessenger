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
  assert(#window.contacts.rows == 2)
  assert(window.title.text == "WhisperMessenger")
  assert(window.title.point[1] == "TOPLEFT")
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
