local FakeUI = require("tests.helpers.fake_ui")

local KEY = "wow::firstmoon"

local function loadAddonFromToc(addonName, ns)
  for line in io.lines("WhisperMessenger.toc") do
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed ~= "" and trimmed:sub(1, 2) ~= "##" and not trimmed:match("%.xml$") then
      local chunk = assert(loadfile(trimmed))
      chunk(addonName, ns)
    end
  end
end

-- The toggle key and /wm run outside a clean hardware event (the key is
-- deferred by KeySettle), where a protected SendWho is blocked. Only a click
-- asks /who, so the key must never reach WhoLookup.TryFor. The real runtime is
-- booted: a stub toggle would prove nothing.
return function()
  local factory = FakeUI.NewFactory()
  local accountState = {
    conversations = {
      [KEY] = {
        displayName = "Firstmoon",
        channel = "WOW",
        unreadCount = 1,
        lastActivityAt = os.time(),
        messages = {},
      },
    },
    contacts = {},
    pendingHydration = {},
    schemaVersion = 1,
    settings = { showPlayerLevels = true },
  }
  local characterState = {
    window = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 920, height = 580, minimized = false },
    icon = { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
  }

  local savedTime = rawget(_G, "time")
  rawset(_G, "time", os.time)
  local ns = {}
  loadAddonFromToc("WhisperMessenger", ns)
  _G.UISpecialFrames = {}
  local runtime = ns.Bootstrap.Initialize(factory, {
    accountState = accountState,
    characterState = characterState,
    localProfileId = "current",
  })
  ns.Bootstrap.runtime = runtime
  assert(ns.DisplayName.ShowPlayerLevels() == true, "Show player levels is on")

  local asked = 0
  local original = ns.WhoLookup.TryFor
  ns.WhoLookup.TryFor = function()
    asked = asked + 1
    return false
  end
  local ok, err = pcall(_G.WhisperMessenger_Toggle)
  ns.WhoLookup.TryFor = original
  ns.DisplayName.Configure({ showPlayerLevels = false })
  rawset(_G, "time", savedTime)
  assert(ok, err)

  -- test_toggle_key_never_asks_who
  assert(runtime.window.frame.shown == true, "the key press opened the window")
  assert(runtime.activeConversationKey == KEY, "the toggle opened onto the stranger's chat, got " .. tostring(runtime.activeConversationKey))
  assert(asked == 0, "the toggle key must not ask /who, asked " .. asked .. " times")
end
