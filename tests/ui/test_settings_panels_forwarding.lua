-- Regression: SettingsPanels.Create must forward every persisted settings key
-- into the per-panel config so that the UI displays the user's saved choice
-- after /reload or relog. Previously `notificationSound`,
-- `widgetPreviewAutoDismissSeconds`, `widgetPreviewPosition`,
-- `bubbleColorPreset`, `timeFormat` and `timeSource` were persisted to
-- accountState.settings but never passed back into the panels, so the panel
-- fell back to its built-in defaults at open time and the player thought the
-- setting had been reset.

local FakeUI = require("tests.helpers.fake_ui")
local SettingsPanels = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.SettingsPanels")

local function captureCreate(capture)
  return function(_factory, _parent, config, _options)
    capture.config = config
    return { frame = {}, refreshLayout = function() end, refreshTheme = function() end }
  end
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  local generalCapture = {}
  local appearanceCapture = {}
  local behaviorCapture = {}
  local notificationCapture = {}

  local settingsConfig = {
    -- general
    clearOnLogout = true,
    hideMessagePreview = true,
    timeFormat = "24h",
    timeSource = "server",
    interfaceLanguage = "ruRU",
    -- appearance
    themePreset = "elvui_dark",
    fontFamily = "friz",
    fontSize = 14,
    fontOutline = "OUTLINE",
    fontColor = "custom",
    bubbleColorPreset = "azeroth",
    windowOpacityInactive = 0.4,
    windowOpacityActive = 0.9,
    nativeChrome = true,
    -- behavior
    dimWhenMoving = false,
    autoFocusComposer = true,
    hideFromDefaultChat = true,
    autoOpenIncoming = true,
    autoOpenOutgoing = true,
    doubleEscapeToClose = true,
    showGroupChats = false,
    -- notifications
    badgePulse = false,
    playSoundOnWhisper = true,
    showUnreadBadge = false,
    notificationSound = "chime",
    iconSize = 56,
    iconDesaturated = false,
    showWidgetMessagePreview = false,
    widgetPreviewAutoDismissSeconds = 15,
    widgetPreviewPosition = "top",
  }

  SettingsPanels.Create(factory, {
    parent = parent,
    settingsConfig = settingsConfig,
    storeConfig = {
      maxMessagesPerConversation = 200,
      maxConversations = 100,
      messageMaxAge = 86400,
    },
    onSettingChanged = function() end,
    generalCreate = captureCreate(generalCapture),
    appearanceCreate = captureCreate(appearanceCapture),
    behaviorCreate = captureCreate(behaviorCapture),
    notificationCreate = captureCreate(notificationCapture),
  })

  -- General: timeFormat and timeSource must round-trip.
  assert(generalCapture.config.timeFormat == "24h", "expected general config.timeFormat=24h, got: " .. tostring(generalCapture.config.timeFormat))
  assert(
    generalCapture.config.timeSource == "server",
    "expected general config.timeSource=server, got: " .. tostring(generalCapture.config.timeSource)
  )
  assert(
    generalCapture.config.interfaceLanguage == "ruRU",
    "expected general config.interfaceLanguage=ruRU, got: " .. tostring(generalCapture.config.interfaceLanguage)
  )

  -- Appearance: bubbleColorPreset must round-trip.
  assert(
    appearanceCapture.config.bubbleColorPreset == "azeroth",
    "expected appearance config.bubbleColorPreset=azeroth, got: " .. tostring(appearanceCapture.config.bubbleColorPreset)
  )

  -- Notifications: notificationSound, widgetPreviewAutoDismissSeconds, and
  -- widgetPreviewPosition must round-trip so the panel shows the persisted
  -- selection on reopen.
  assert(
    notificationCapture.config.notificationSound == "chime",
    "expected notification config.notificationSound=chime, got: " .. tostring(notificationCapture.config.notificationSound)
  )
  assert(
    notificationCapture.config.widgetPreviewAutoDismissSeconds == 15,
    "expected notification config.widgetPreviewAutoDismissSeconds=15, got: " .. tostring(notificationCapture.config.widgetPreviewAutoDismissSeconds)
  )
  assert(
    notificationCapture.config.widgetPreviewPosition == "top",
    "expected notification config.widgetPreviewPosition=top, got: " .. tostring(notificationCapture.config.widgetPreviewPosition)
  )
end
