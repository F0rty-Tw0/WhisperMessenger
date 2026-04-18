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
          lastIncomingSender = "Arthas-Area52",
          lastIncomingPreview = "Need help?",
          lastIncomingAt = 20,
          channel = "WOW",
          messages = {},
        },
        ["me::WOW::jaina-proudmoore"] = {
          displayName = "Jaina-Proudmoore",
          unreadCount = 3,
          lastPreview = "On my way.",
          lastActivityAt = 10,
          lastIncomingSender = "Jaina-Proudmoore",
          lastIncomingPreview = "Need assistance?",
          lastIncomingAt = 10,
          channel = "WOW",
          messages = {},
        },
        ["alt::WOW::thrall-draenor"] = {
          displayName = "Thrall-Draenor",
          unreadCount = 9,
          lastPreview = "Lok'tar.",
          lastActivityAt = 30,
          lastIncomingSender = "Thrall-Draenor",
          lastIncomingPreview = "Lok'tar.",
          lastIncomingAt = 30,
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

  assert(runtime.icon.previewFrame ~= nil, "expected preview frame on draggable widget")
  assert(runtime.icon.previewFrame.shown == true, "expected preview to show when an incoming message exists")
  assert(runtime.icon.previewSenderLabel.text == "Thrall-Draenor")
  assert(runtime.icon.previewMessageLabel.text == "Lok'tar.")

  assert(type(runtime.icon.frame.scripts.OnClick) == "function")
  runtime.icon.frame.scripts.OnClick(runtime.icon.frame)
  assert(runtime.window.frame.shown == true)
  assert(runtime.icon.previewFrame.shown == false, "expected opening chat to clear the preview")
  runtime.refreshWindow()
  assert(
    runtime.icon.previewFrame.shown == false,
    "expected cleared preview to stay hidden until a newer message arrives"
  )
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

  runtime.accountState.conversations["wow::WOW::jaina-proudmoore"].lastIncomingSender = "Jaina-Proudmoore"
  runtime.accountState.conversations["wow::WOW::jaina-proudmoore"].lastIncomingPreview = "Meet by the bank."
  runtime.accountState.conversations["wow::WOW::jaina-proudmoore"].lastIncomingAt = 40
  runtime.refreshWindow()
  assert(runtime.icon.previewSenderLabel.text == "Jaina-Proudmoore")
  assert(runtime.icon.previewMessageLabel.text == "Meet by the bank.")

  runtime.accountState.settings.showWidgetMessagePreview = false
  runtime.refreshWindow()
  assert(
    runtime.icon.previewFrame.shown == false,
    "expected preview to hide when widget message preview setting is disabled"
  )
  runtime.accountState.settings.showWidgetMessagePreview = true
  runtime.refreshWindow()
  assert(runtime.icon.previewSenderLabel.text == "Jaina-Proudmoore")
  assert(runtime.icon.previewMessageLabel.text == "Meet by the bank.")

  assert(runtime.icon.previewDismissButton ~= nil, "expected preview dismiss button on draggable widget")
  runtime.icon.previewDismissButton.scripts.OnClick(runtime.icon.previewDismissButton)
  assert(runtime.icon.previewFrame.shown == false, "expected dismiss button to hide the preview")
  runtime.refreshWindow()
  assert(
    runtime.icon.previewFrame.shown == false,
    "expected dismissed preview to stay hidden until a newer message arrives"
  )
  runtime.accountState.conversations["wow::WOW::jaina-proudmoore"].lastIncomingAt = 41
  runtime.refreshWindow()
  assert(runtime.icon.previewSenderLabel.text == "Jaina-Proudmoore")
  assert(runtime.icon.previewMessageLabel.text == "Meet by the bank.")

  runtime.accountState.conversations["wow::WOW::arthas-area52"].lastIncomingSender = nil
  runtime.accountState.conversations["wow::WOW::arthas-area52"].lastIncomingPreview = nil
  runtime.accountState.conversations["wow::WOW::arthas-area52"].lastIncomingAt = nil
  runtime.accountState.conversations["wow::WOW::jaina-proudmoore"].lastIncomingSender = nil
  runtime.accountState.conversations["wow::WOW::jaina-proudmoore"].lastIncomingPreview = nil
  runtime.accountState.conversations["wow::WOW::jaina-proudmoore"].lastIncomingAt = nil

  runtime.accountState.conversations["wow::WOW::thrall-draenor"].lastIncomingSender = nil
  runtime.accountState.conversations["wow::WOW::thrall-draenor"].lastIncomingPreview = nil
  runtime.accountState.conversations["wow::WOW::thrall-draenor"].lastIncomingAt = nil
  runtime.accountState.conversations["wow::WOW::arthas-area52"].unreadCount = 0
  runtime.accountState.conversations["wow::WOW::jaina-proudmoore"].unreadCount = 0
  runtime.accountState.conversations["wow::WOW::thrall-draenor"].unreadCount = 0
  runtime.refreshWindow()
  assert(runtime.icon.previewFrame.shown == false, "expected preview to hide when no incoming preview exists")

  assert(runtime.icon.badgeLabel.text == "")
  assert(runtime.icon.badge.shown == false)

  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
end
