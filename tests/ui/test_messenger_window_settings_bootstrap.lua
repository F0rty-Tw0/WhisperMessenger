-- focused settings-panels bootstrap regression
local FakeUI = require("tests.helpers.fake_ui")
local SettingsPanelsBootstrap = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanelsBootstrap")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local capturedFactory = nil
  local capturedOptions = nil
  local fakeRuntime = {
    generalPanel = { tag = "general" },
    generalSettings = { tag = "generalSettings" },
    appearancePanel = { tag = "appearance" },
    appearanceSettings = { tag = "appearanceSettings" },
    behaviorPanel = { tag = "behavior" },
    behaviorSettings = { tag = "behaviorSettings" },
    notificationsPanel = { tag = "notifications" },
    notificationSettings = { tag = "notificationSettings" },
    refreshThemeVisuals = function() end,
    setThemeTargets = function(_, _) end,
  }

  local function fakeRuntimeCreate(f, opts)
    capturedFactory = f
    capturedOptions = opts
    return fakeRuntime
  end

  local theme = { COLORS = {} }
  local chrome = { tag = "chrome" }
  local layout = { tag = "layout" }
  local settingsConfig = { autoFocusComposer = true }
  local storeConfig = { maxConversations = 100 }
  local function onSettingChanged(_, _) end

  local result = SettingsPanelsBootstrap.Create(factory, {
    parent = parent,
    settingsConfig = settingsConfig,
    storeConfig = storeConfig,
    onSettingChanged = onSettingChanged,
    theme = theme,
    chrome = chrome,
    layout = layout,
    settingsRuntimeCreate = fakeRuntimeCreate,
  })

  assert(capturedFactory == factory, "expected factory to be forwarded to SettingsRuntime.Create")
  assert(capturedOptions ~= nil, "expected options to reach SettingsRuntime.Create")
  assert(capturedOptions.parent == parent, "expected parent forwarded")
  assert(capturedOptions.settingsConfig == settingsConfig, "expected settingsConfig forwarded")
  assert(capturedOptions.storeConfig == storeConfig, "expected storeConfig forwarded")
  assert(capturedOptions.onSettingChanged == onSettingChanged, "expected onSettingChanged forwarded")
  assert(capturedOptions.theme == theme, "expected theme forwarded")
  assert(capturedOptions.chrome == chrome, "expected chrome forwarded")
  assert(capturedOptions.layout == layout, "expected layout forwarded")

  assert(result.generalPanel == fakeRuntime.generalPanel, "expected generalPanel passthrough")
  assert(result.generalSettings == fakeRuntime.generalSettings, "expected generalSettings passthrough")
  assert(result.appearancePanel == fakeRuntime.appearancePanel, "expected appearancePanel passthrough")
  assert(result.appearanceSettings == fakeRuntime.appearanceSettings, "expected appearanceSettings passthrough")
  assert(result.behaviorPanel == fakeRuntime.behaviorPanel, "expected behaviorPanel passthrough")
  assert(result.behaviorSettings == fakeRuntime.behaviorSettings, "expected behaviorSettings passthrough")
  assert(result.notificationsPanel == fakeRuntime.notificationsPanel, "expected notificationsPanel passthrough")
  assert(result.notificationSettings == fakeRuntime.notificationSettings, "expected notificationSettings passthrough")
  assert(result.refreshThemeVisuals == fakeRuntime.refreshThemeVisuals, "expected refreshThemeVisuals passthrough")
  assert(type(result.setThemeTargets) == "function", "expected setThemeTargets to be exposed")
end
