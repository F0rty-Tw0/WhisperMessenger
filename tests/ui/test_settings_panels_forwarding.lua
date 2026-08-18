-- Regression: SettingsPanels.Create must forward every persisted settings key
-- to its owning panel so saved choices survive /reload or relog.

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
  local iconsCapture = {}

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
    -- notifications and icons
    lockToggleIcon = true,
    shareWidgetPosition = true,
    badgePulse = false,
    playSoundOnWhisper = true,
    showUnreadBadge = false,
    notificationSound = "chime",
    iconSize = 56,
    iconDesaturated = false,
    showWidgetMessagePreview = false,
    transparentWidget = true,
    widgetTransparency = 0.4,
    widgetPreviewAutoDismissSeconds = 15,
    iconMode = "both",
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
    iconCreate = captureCreate(iconsCapture),
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

  -- Notifications owns sound settings only.
  assert(
    notificationCapture.config.playSoundOnWhisper == true,
    "expected notification config.playSoundOnWhisper=true, got: " .. tostring(notificationCapture.config.playSoundOnWhisper)
  )
  assert(
    notificationCapture.config.notificationSound == "chime",
    "expected notification config.notificationSound=chime, got: " .. tostring(notificationCapture.config.notificationSound)
  )
  assert(notificationCapture.config.iconMode == nil, "Notifications config should not include iconMode")
  assert(notificationCapture.config.iconSize == nil, "Notifications config should not include iconSize")

  assert(iconsCapture.config.iconMode == "both", "expected icons config.iconMode=both, got: " .. tostring(iconsCapture.config.iconMode))
  assert(iconsCapture.config.iconSize == 56, "expected icons config.iconSize=56, got: " .. tostring(iconsCapture.config.iconSize))
  assert(
    iconsCapture.config.iconDesaturated == false,
    "expected icons config.iconDesaturated=false, got: " .. tostring(iconsCapture.config.iconDesaturated)
  )
  assert(
    iconsCapture.config.lockToggleIcon == true,
    "expected icons config.lockToggleIcon=true, got: " .. tostring(iconsCapture.config.lockToggleIcon)
  )
  assert(
    iconsCapture.config.shareWidgetPosition == true,
    "expected icons config.shareWidgetPosition=true, got: " .. tostring(iconsCapture.config.shareWidgetPosition)
  )
  assert(
    iconsCapture.config.showUnreadBadge == false,
    "expected icons config.showUnreadBadge=false, got: " .. tostring(iconsCapture.config.showUnreadBadge)
  )
  assert(iconsCapture.config.badgePulse == false, "expected icons config.badgePulse=false, got: " .. tostring(iconsCapture.config.badgePulse))
  assert(
    iconsCapture.config.showWidgetMessagePreview == false,
    "expected icons config.showWidgetMessagePreview=false, got: " .. tostring(iconsCapture.config.showWidgetMessagePreview)
  )
  assert(iconsCapture.config.transparentWidget == nil, "Icons config should not include transparentWidget")
  assert(
    iconsCapture.config.widgetTransparency == 0.4,
    "expected icons config.widgetTransparency=0.4, got: " .. tostring(iconsCapture.config.widgetTransparency)
  )
  assert(
    iconsCapture.config.widgetPreviewAutoDismissSeconds == 15,
    "expected icons config.widgetPreviewAutoDismissSeconds=15, got: " .. tostring(iconsCapture.config.widgetPreviewAutoDismissSeconds)
  )
  assert(
    iconsCapture.config.widgetPreviewPosition == "top",
    "expected icons config.widgetPreviewPosition=top, got: " .. tostring(iconsCapture.config.widgetPreviewPosition)
  )
end
