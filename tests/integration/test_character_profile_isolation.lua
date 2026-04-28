local Bootstrap = require("WhisperMessenger.Bootstrap")
local Router = require("WhisperMessenger.Core.EventRouter")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
  local savedUnitFullName = _G.UnitFullName
  local savedGetNormalizedRealmName = _G.GetNormalizedRealmName

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil

  local accountState = {
    schemaVersion = 1,
    conversations = {},
    contacts = {},
    pendingHydration = {},
  }

  local arthasCharacterState = {
    window = { x = 0, y = 0, width = 900, height = 560, minimized = false },
    icon = { x = 0, y = 0 },
  }

  rawset(_G, "UnitFullName", function(unit)
    assert(unit == "player")
    return "Arthas", "Area52"
  end)

  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)

  local arthasRuntime = Bootstrap.Initialize(factory, {
    accountState = accountState,
    characterState = arthasCharacterState,
  })

  assert(arthasRuntime.localProfileId == "arthas-area52")

  Router.HandleEvent(arthasRuntime, "CHAT_MSG_WHISPER", {
    text = "Need help?",
    playerName = "Jaina-Proudmoore",
    lineID = 101,
    guid = "Player-60-0ABCDE123",
  })

  assert(accountState.conversations["wow::WOW::jaina-proudmoore"].unreadCount == 1)

  EventBridge.RouteChannelEvent(arthasRuntime, "CHAT_MSG_CHANNEL", "WTS [Thunderfury] 50k", "Jaina-Proudmoore", "", "2. Trade - Stormwind City")

  local thrallCharacterState = {
    window = { x = 0, y = 0, width = 900, height = 560, minimized = false },
    icon = { x = 0, y = 0 },
  }

  rawset(_G, "UnitFullName", function(unit)
    assert(unit == "player")
    return "Thrall", "Draenor"
  end)

  rawset(_G, "GetNormalizedRealmName", function()
    return "Draenor"
  end)

  local thrallRuntime = Bootstrap.Initialize(factory, {
    accountState = accountState,
    characterState = thrallCharacterState,
  })

  assert(thrallRuntime.localProfileId == "thrall-draenor")
  local sharedChannelEntry = ChannelMessageStore.GetLatest(thrallRuntime.channelMessageStore, "jaina-proudmoore", arthasRuntime.now())
  assert(sharedChannelEntry ~= nil, "expected channel context to persist across character switches")
  assert(
    sharedChannelEntry.text == "WTS [Thunderfury] 50k",
    "shared channel text mismatch: " .. tostring(sharedChannelEntry and sharedChannelEntry.text)
  )
  assert(thrallRuntime.icon.badge.shown == true, "expected badge visible before toggle")
  thrallRuntime.ensureWindow()
  assert(#thrallRuntime.window.contacts.rows == 1)
  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  rawset(_G, "UnitFullName", savedUnitFullName)
  rawset(_G, "GetNormalizedRealmName", savedGetNormalizedRealmName)
end
