local FakeUI = require("tests.helpers.fake_ui")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local Localization = require("WhisperMessenger.Locale.Localization")

local function initialize(settings)
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  local savedSuspended = _G._wmSuspended
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G._wmSuspended = nil

  local ok, runtime = pcall(Bootstrap.Initialize, factory, {
    accountState = {
      schemaVersion = 1,
      conversations = {},
      contacts = {},
      pendingHydration = {},
      settings = settings,
    },
    characterState = {
      window = { x = 0, y = 0, width = 900, height = 560 },
      icon = {},
    },
  })

  _G.UIParent = savedUIParent
  _G._wmSuspended = savedSuspended
  assert(ok, runtime)
  return runtime
end

return function()
  -- test_startup_keeps_only_the_saved_language
  assert(Localization.IsLanguageLoaded("ruRU") == true, "every catalog is loaded before startup")
  initialize({ interfaceLanguage = "deDE" })
  assert(Localization.IsLanguageLoaded("deDE") == true, "startup keeps the saved language")
  assert(Localization.IsLanguageLoaded("ruRU") == false, "startup drops other languages")
  assert(Localization.Text("General Settings") == "Allgemeine Einstellungen", "active language still translates")
end
