local SavedState = require("WhisperMessenger.Persistence.SavedState")
local ContactsList = require("WhisperMessenger.UI.ContactsList")

return function()
  local account, character = SavedState.Initialize(nil, nil)

  account.conversations["me::WOW::jaina-proudmoore"] = {
    displayName = "Jaina-Proudmoore",
    unreadCount = 2,
    lastPreview = "Need assistance?",
    lastActivityAt = 20,
    messages = { { text = "Need assistance?" } },
  }

  account.conversations["me::WOW::anduin-stormrage"] = {
    displayName = "Anduin-Stormrage",
    unreadCount = 0,
    lastPreview = "On my way.",
    lastActivityAt = 10,
    messages = { { text = "On my way." } },
  }

  account.conversations["alt::WOW::thrall-draenor"] = {
    displayName = "Thrall-Draenor",
    unreadCount = 4,
    lastPreview = "Lok'tar.",
    lastActivityAt = 30,
    messages = { { text = "Lok'tar." } },
  }

  character.activeConversationKey = "me::WOW::jaina-proudmoore"

  local currentProfile = SavedState.ListProfileConversations(account, "me")
  local items = ContactsList.BuildItems(currentProfile)
  local _, reloadedCharacter = SavedState.Initialize(account, character)

  assert(items[1].displayName == "Jaina-Proudmoore")
  assert(items[2].displayName == "Anduin-Stormrage")
  assert(character.window.width == 900)
  assert(character.window.height == 560)
  assert(reloadedCharacter.activeConversationKey == "me::WOW::jaina-proudmoore")
end
