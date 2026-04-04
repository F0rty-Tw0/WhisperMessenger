local Bootstrap = require("WhisperMessenger.Bootstrap")
local FakeUI = require("tests.helpers.fake_ui")
local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")

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
          unreadCount = 0,
          lastPreview = "",
          lastActivityAt = 10,
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

  -- Spy on ContactEnricher.BuildWindowSelectionState
  local enricherCallCount = 0
  local originalBuildState = ContactEnricher.BuildWindowSelectionState
  rawset(ContactEnricher, "BuildWindowSelectionState", function(...)
    enricherCallCount = enricherCallCount + 1
    return originalBuildState(...)
  end)

  -- TEST 1: refreshWindow ALWAYS calls enricher (even when window hidden)
  -- This is the critical fix: statuses must stay fresh regardless of visibility
  assert(runtime.window == nil, "window should be nil before toggle")
  enricherCallCount = 0
  runtime.refreshWindow()
  runtime.refreshWindow()
  runtime.refreshWindow()
  assert(enricherCallCount == 3, "expected enricher called 3 times even when window hidden, got " .. enricherCallCount)

  -- Verify icon badge still updates
  local conv = (next(runtime.store.conversations) and runtime.store.conversations[next(runtime.store.conversations)])
  assert(conv ~= nil, "expected at least one conversation in store")
  conv.unreadCount = 3
  runtime.refreshWindow()
  assert(runtime.icon.badgeLabel.text == "3", "expected icon badge to update even when window hidden")

  -- TEST 2: visible refreshWindow enriches contacts and pushes selection into the window
  runtime.toggle() -- creates and shows window
  assert(runtime.window ~= nil, "expected window after toggle")
  assert(runtime.window.frame.shown == true, "expected window visible after toggle")

  local selectionRefreshCount = 0
  local originalRefreshSelection = runtime.window.refreshSelection
  runtime.window.refreshSelection = function(...)
    selectionRefreshCount = selectionRefreshCount + 1
    return originalRefreshSelection(...)
  end

  enricherCallCount = 0
  selectionRefreshCount = 0
  runtime.refreshWindow()
  assert(enricherCallCount >= 1, "expected enricher called when window visible, got " .. enricherCallCount)
  assert(
    selectionRefreshCount == 1,
    "expected visible refreshWindow to push selection once, got " .. selectionRefreshCount
  )

  -- TEST 3: hidden refreshWindow still enriches contacts without touching visible selection
  runtime.toggle() -- hide window
  assert(runtime.window.frame.shown == false, "expected window hidden after second toggle")

  enricherCallCount = 0
  selectionRefreshCount = 0
  runtime.refreshWindow()
  assert(enricherCallCount == 1, "expected enricher called even after window hidden again, got " .. enricherCallCount)
  assert(
    selectionRefreshCount == 0,
    "expected hidden refreshWindow to skip pushing selection, got " .. selectionRefreshCount
  )
  -- Icon badge should still update
  conv.unreadCount = 7
  runtime.refreshWindow()
  assert(runtime.icon.badgeLabel.text == "7", "expected icon badge update when window hidden")

  -- Restore
  rawset(ContactEnricher, "BuildWindowSelectionState", originalBuildState)
  _G.UIParent = savedUIParent
  _G.SlashCmdList = savedSlashCmdList
  _G.SLASH_WHISPERMESSENGER1 = savedSlash1
  _G.SLASH_WHISPERMESSENGER2 = savedSlash2
end
