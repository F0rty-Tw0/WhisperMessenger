local Bootstrap = require("WhisperMessenger.Bootstrap")
local FakeUI = require("tests.helpers.fake_ui")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

return function()
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedSlashCmdList = _G.SlashCmdList
  local savedSlash1 = _G.SLASH_WHISPERMESSENGER1
  local savedSlash2 = _G.SLASH_WHISPERMESSENGER2
  local rebuildCount = 0
  local savedRebuild = PresenceCache.Rebuild
  rawset(PresenceCache, "Rebuild", function()
    rebuildCount = rebuildCount + 1
    return savedRebuild()
  end)

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

  -- TEST 1: window is NOT created at initialize time
  assert(runtime.window == nil, "expected window to be nil after Initialize (lazy)")
  assert(runtime.icon ~= nil, "expected icon to be created eagerly")
  assert(type(runtime.toggle) == "function", "expected toggle to be a function")

  -- TEST 2: refreshWindow is a no-op for UI before window creation
  runtime.refreshWindow()
  assert(runtime.window == nil, "expected refreshWindow to NOT force window creation")

  -- TEST 3: icon badge updates even without window
  assert(runtime.icon.badgeLabel.text == "2", "expected icon badge to show unread count")

  -- TEST 4: window is created on first toggle and rebuilds presence on open
  runtime.toggle()
  assert(runtime.window ~= nil, "expected window to be created on first toggle")
  assert(runtime.window.frame.shown == true, "expected window to be visible after toggle")
  assert(rebuildCount == 1, "expected PresenceCache.Rebuild once on first open, got " .. rebuildCount)

  -- TEST 5: second toggle hides the window
  runtime.toggle()
  assert(runtime.window.frame.shown == false, "expected window to be hidden after second toggle")

  -- TEST 6: refreshWindow works normally after window creation
  runtime.refreshWindow()
  assert(runtime.window ~= nil, "expected window to still exist after refresh")

  rawset(PresenceCache, "Rebuild", savedRebuild)
  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
end
