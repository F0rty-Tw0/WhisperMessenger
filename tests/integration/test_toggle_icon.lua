local Bootstrap = require("WhisperMessenger.Bootstrap")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2

  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.SlashCmdList = {}
  _G.SLASH_WHISPERMESSENGER1 = nil
  _G.SLASH_WHISPERMESSENGER2 = nil

  local runtime = Bootstrap.Initialize(factory, {
    accountState = {
      schemaVersion = 1,
      conversations = {
        ["me::WOW::arthas-area52"] = {
          displayName = "Arthas-Area52",
          unreadCount = 2,
          lastPreview = "Need help?",
          lastActivityAt = 20,
          channel = "WOW",
          messages = {},
        },
        ["me::WOW::jaina-proudmoore"] = {
          displayName = "Jaina-Proudmoore",
          unreadCount = 3,
          lastPreview = "On my way.",
          lastActivityAt = 10,
          channel = "WOW",
          messages = {},
        },
        ["alt::WOW::thrall-draenor"] = {
          displayName = "Thrall-Draenor",
          unreadCount = 9,
          lastPreview = "Lok'tar.",
          lastActivityAt = 30,
          channel = "WOW",
          messages = {},
        },
      },
      contacts = {},
      pendingHydration = {},
    },
    characterState = {
      window = { x = 0, y = 0, width = 900, height = 560, minimized = false },
      icon = {
        anchorPoint = "TOPLEFT",
        relativePoint = "TOPLEFT",
        x = 25,
        y = -40,
      },
    },
    localProfileId = "me",
  })

  assert(runtime.icon ~= nil)
  assert(runtime.icon.frame.parent == _G.UIParent)
  assert(runtime.icon.frame.point[1] == "TOPLEFT")
  assert(runtime.icon.frame.point[4] == 25)
  assert(runtime.icon.frame.point[5] == -40)
  assert(runtime.window == nil, "expected window to be nil before toggle (lazy)")
  assert(runtime.icon.badge ~= nil)
  assert(runtime.icon.badgeLabel.text == "14")
  assert(runtime.icon.badge.shown == true)

  assert(type(runtime.icon.frame.scripts.OnClick) == "function")
  runtime.icon.frame.scripts.OnClick(runtime.icon.frame)
  assert(runtime.window.frame.shown == true)
  runtime.icon.frame.scripts.OnClick(runtime.icon.frame)
  assert(runtime.window.frame.shown == false)

  assert(type(runtime.icon.frame.scripts.OnDragStart) == "function")
  assert(type(runtime.icon.frame.scripts.OnDragStop) == "function")
  runtime.icon.frame.scripts.OnDragStart(runtime.icon.frame)
  assert(runtime.icon.frame.startedMoving == true)

  runtime.icon.frame:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 75, 90)
  runtime.icon.frame.scripts.OnDragStop(runtime.icon.frame)
  assert(runtime.icon.frame.stoppedMoving == true)
  assert(runtime.characterState.icon.anchorPoint == "BOTTOMLEFT")
  assert(runtime.characterState.icon.relativePoint == "BOTTOMLEFT")
  assert(runtime.characterState.icon.x == 75)
  assert(runtime.characterState.icon.y == 90)

  runtime.accountState.conversations["wow::WOW::arthas-area52"].unreadCount = 0
  runtime.accountState.conversations["wow::WOW::jaina-proudmoore"].unreadCount = 0
  runtime.accountState.conversations["wow::WOW::thrall-draenor"].unreadCount = 0
  runtime.refreshWindow()
  assert(runtime.icon.badgeLabel.text == "")
  assert(runtime.icon.badge.shown == false)

  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
end
