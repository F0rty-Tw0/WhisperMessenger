local SavedState = require("WhisperMessenger.Persistence.SavedState")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")
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
  assert(reloadedCharacter.activeConversationKey == "wow::WOW::jaina-proudmoore")

  -- test_channel_messages_persist_across_relog
  do
    local accountState, characterState = SavedState.Initialize(nil, nil, "arthas-area52")
    local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, "arthas-area52", {
      now = function()
        return 5000
      end,
    })

    EventBridge.RouteChannelEvent(runtime, "CHAT_MSG_CHANNEL", "WTS [Thunderfury] 50k", "Arthas-Area52", "", "2. Trade - Stormwind City")

    local reloadedAccount, reloadedCharacterState = SavedState.Initialize(accountState, characterState, "arthas-area52")
    local reloadedRuntime = RuntimeFactory.CreateRuntimeState(reloadedAccount, reloadedCharacterState, "arthas-area52", {
      now = function()
        return 5000
      end,
    })

    local entry = ChannelMessageStore.GetLatest(reloadedRuntime.channelMessageStore, "arthas-area52", 5000)
    assert(entry ~= nil, "expected channel context to survive relog")
    assert(entry.text == "WTS [Thunderfury] 50k", "reloaded channel text mismatch")
    assert(entry.channelLabel == "Trade", "reloaded channel label mismatch")
  end

  -- test_channel_messages_persist_across_character_switch
  do
    local accountState, arthasCharacterState = SavedState.Initialize(nil, nil, "arthas-area52")
    local arthasRuntime = RuntimeFactory.CreateRuntimeState(accountState, arthasCharacterState, "arthas-area52", {
      now = function()
        return 5000
      end,
    })

    EventBridge.RouteChannelEvent(arthasRuntime, "CHAT_MSG_CHANNEL", "WTS [Thunderfury] 50k", "Traderjoe-Area52", "", "2. Trade - Stormwind City")

    local reloadedAccount, thrallCharacterState = SavedState.Initialize(accountState, nil, "thrall-draenor")
    local thrallRuntime = RuntimeFactory.CreateRuntimeState(reloadedAccount, thrallCharacterState, "thrall-draenor", {
      now = function()
        return 5000
      end,
    })

    local entry = ChannelMessageStore.GetLatest(thrallRuntime.channelMessageStore, "traderjoe-area52", 5000)
    assert(entry ~= nil, "expected channel context to persist across character switch")
    assert(entry.text == "WTS [Thunderfury] 50k", "cross-character channel text mismatch")
  end
end
