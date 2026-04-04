local Bootstrap = require("WhisperMessenger.Bootstrap")
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
  rawset(_G, "UnitFullName", function(unit)
    assert(unit == "player")
    return "Arthas", "Area52"
  end)
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)

  local accountState = {
    schemaVersion = 1,
    conversations = {
      ["current::WOW::jaina-proudmoore"] = {
        displayName = "Jaina-Proudmoore",
        unreadCount = 2,
        lastPreview = "Need assistance?",
        lastActivityAt = 20,
        channel = "WOW",
        messages = {
          { direction = "in", kind = "user", text = "Need assistance?" },
        },
      },
    },
    contacts = {},
    pendingHydration = {},
  }

  local characterState = {
    window = { x = 0, y = 0, width = 900, height = 560, minimized = false },
    icon = { x = 0, y = 0 },
    activeConversationKey = "current::WOW::jaina-proudmoore",
  }

  local runtime = Bootstrap.Initialize(factory, {
    accountState = accountState,
    characterState = characterState,
  })

  local migratedKey = "wow::WOW::jaina-proudmoore"
  assert(runtime.localProfileId == "arthas-area52")
  assert(
    accountState.conversations[migratedKey] ~= nil,
    "expected legacy current conversation to migrate to the resolved profile"
  )
  assert(
    accountState.conversations["current::WOW::jaina-proudmoore"] == nil,
    "expected legacy current conversation key to be removed after migration"
  )
  assert(characterState.activeConversationKey == migratedKey, "expected active conversation to follow the migrated key")
  assert(runtime.icon.badgeLabel.text == "2", "expected migrated unread count to remain visible")
  runtime.ensureWindow()
  assert(
    runtime.window.contacts.rows[1].item.conversationKey == migratedKey,
    "expected migrated conversation to appear in contacts"
  )

  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
  rawset(_G, "UnitFullName", savedUnitFullName)
  rawset(_G, "GetNormalizedRealmName", savedGetNormalizedRealmName)
end
